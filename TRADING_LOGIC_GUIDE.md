# NOFX 交易系统基本逻辑说明

## 📋 目录
1. [系统架构概览](#系统架构概览)
2. [决策流程](#决策流程)
3. [开仓逻辑](#开仓逻辑)
4. [平仓逻辑](#平仓逻辑)
5. [止盈止损机制](#止盈止损机制)
6. [风险控制](#风险控制)
7. [交易执行流程](#交易执行流程)

---

## 🏗️ 系统架构概览

### 核心组件
- **决策引擎** (`decision/engine.go`): AI决策生成和验证
- **交易执行器** (`trader/auto_trader.go`): 决策执行和订单管理
- **交易接口** (`trader/binance_futures.go`, `trader/hyperliquid_trader.go`): 交易所API封装
- **日志系统** (`logger/decision_logger.go`): 交易记录和性能分析

### 支持的交易动作
```go
type Decision struct {
    Symbol          string  // 交易币种 (如 "BTCUSDT")
    Action          string  // 交易动作: "open_long", "open_short", "close_long", "close_short", "hold", "wait"
    Leverage        int     // 杠杆倍数
    PositionSizeUSD float64 // 仓位价值(USD)
    StopLoss        float64 // 止损价格
    TakeProfit      float64 // 止盈价格
    Confidence      int     // 信心度 (0-100)
    RiskUSD         float64 // 最大风险金额
    Reasoning       string  // 决策理由
}
```

---

## 🔄 决策流程

### 1. 数据收集阶段
```
市场数据获取 → 技术指标计算 → 持仓状态检查 → 账户信息更新
```

### 2. AI分析阶段
```
System Prompt (固定规则) + User Prompt (动态数据) → AI分析 → 生成决策JSON
```

### 3. 决策验证阶段
```
参数合法性检查 → 风险控制验证 → 仓位限制检查 → 止损止盈验证
```

### 4. 执行阶段
```
决策排序(平仓优先) → 逐个执行 → 设置止损止盈 → 记录日志
```

---

## 📈 开仓逻辑

### 开多仓 (`open_long`)

#### 执行条件
- ✅ 通过所有验证规则
- ✅ 无同币种同方向持仓
- ✅ 账户余额充足
- ✅ 信心度 ≥ 75%

#### 执行步骤
1. **防重复检查**: 检查是否已有同币种多仓
2. **取消旧单**: 清理该币种所有挂单
3. **设置杠杆**: 根据币种类型设置杠杆
4. **设置保证金模式**: 逐仓模式
5. **下市价单**: 按计算数量开多仓
6. **设置止损止盈**: 自动设置保护单

#### 代码示例
```go
// 检查重复持仓
for _, pos := range positions {
    if pos["symbol"] == decision.Symbol && pos["side"] == "long" {
        return fmt.Errorf("❌ %s 已有多仓，拒绝开仓", decision.Symbol)
    }
}

// 计算数量
quantity := decision.PositionSizeUSD / marketData.CurrentPrice

// 执行开仓
order, err := at.trader.OpenLong(decision.Symbol, quantity, decision.Leverage)

// 设置保护单
at.trader.SetStopLoss(decision.Symbol, "LONG", quantity, decision.StopLoss)
at.trader.SetTakeProfit(decision.Symbol, "LONG", quantity, decision.TakeProfit)
```

### 开空仓 (`open_short`)

#### 执行逻辑
与开多仓类似，但方向相反：
- 下卖单开空仓
- 止损价格 > 当前价格
- 止盈价格 < 当前价格

---

## 📉 平仓逻辑

### 平多仓 (`close_long`)

#### 执行条件
- ✅ 存在对应的多仓持仓
- ✅ 持仓数量 > 0

#### 执行步骤
1. **获取持仓**: 查找对应币种的多仓
2. **计算数量**: 如果未指定则全部平仓
3. **下市价单**: 卖出平仓
4. **取消挂单**: 清理所有止损止盈单
5. **记录结果**: 计算盈亏并记录

#### 代码示例
```go
// 获取持仓数量
if quantity == 0 {
    for _, pos := range positions {
        if pos["symbol"] == symbol && pos["side"] == "long" {
            quantity = pos["positionAmt"].(float64)
            break
        }
    }
}

// 执行平仓
order, err := t.CloseLong(symbol, quantity)

// 取消挂单
t.CancelAllOrders(symbol)
```

### 平空仓 (`close_short`)

#### 执行逻辑
与平多仓类似，但方向相反：
- 买入平空仓
- 清理对应的止损止盈单

---

## 🎯 止盈止损机制

### 止损单设置

#### 多仓止损
```go
// 多仓止损 = 卖出止损单
// 触发条件: 市价 ≤ 止损价
stopOrder := {
    Symbol: symbol,
    Side: "SELL",
    Type: "STOP_MARKET",
    StopPrice: stopLossPrice,
    Quantity: quantity,
    ReduceOnly: true  // 只平仓
}
```

#### 空仓止损
```go
// 空仓止损 = 买入止损单  
// 触发条件: 市价 ≥ 止损价
stopOrder := {
    Symbol: symbol,
    Side: "BUY", 
    Type: "STOP_MARKET",
    StopPrice: stopLossPrice,
    Quantity: quantity,
    ReduceOnly: true
}
```

### 止盈单设置

#### 多仓止盈
```go
// 多仓止盈 = 卖出限价单
// 触发条件: 市价 ≥ 止盈价
takeProfitOrder := {
    Symbol: symbol,
    Side: "SELL",
    Type: "TAKE_PROFIT_MARKET", 
    StopPrice: takeProfitPrice,
    Quantity: quantity,
    ReduceOnly: true
}
```

#### 空仓止盈
```go
// 空仓止盈 = 买入限价单
// 触发条件: 市价 ≤ 止盈价  
takeProfitOrder := {
    Symbol: symbol,
    Side: "BUY",
    Type: "TAKE_PROFIT_MARKET",
    StopPrice: takeProfitPrice, 
    Quantity: quantity,
    ReduceOnly: true
}
```

### 自动触发机制
- **止损**: 市价触及止损价时自动执行市价单平仓
- **止盈**: 市价触及止盈价时自动执行市价单平仓
- **优先级**: 止损优先于止盈（风险控制优先）

---

## ⚖️ 风险控制

### 开仓前验证

#### 1. 杠杆限制
```go
// BTC/ETH: 最大20倍杠杆
// 山寨币: 最大10倍杠杆
maxLeverage := altcoinLeverage // 默认山寨币
if symbol == "BTCUSDT" || symbol == "ETHUSDT" {
    maxLeverage = btcEthLeverage
}
```

#### 2. 仓位限制
```go
// BTC/ETH: 最大10倍账户净值
// 山寨币: 最大1.5倍账户净值
maxPositionValue := accountEquity * 1.5 // 山寨币
if symbol == "BTCUSDT" || symbol == "ETHUSDT" {
    maxPositionValue = accountEquity * 10 // BTC/ETH
}
```

#### 3. 止损距离验证
```go
// ETH/BTC: 最小4.5% (智能容错)
// 其他币种: 最小5.0%
minStopLossDistance := 0.05 // 默认5%
if symbol == "ETHUSDT" || symbol == "BTCUSDT" {
    minStopLossDistance = 0.045 // 4.5%容错
}
```

#### 4. 风险回报比验证
```go
// 根据信心度要求不同的风险回报比
// ≥85%: 最低3.0:1
// 80-84%: 最低2.5:1  
// 75-79%: 最低2.0:1
```

#### 5. 账户风险验证
```go
// 单笔风险控制在2-10%之间
riskPercent := (positionSizeUSD * stopLossDistance) / accountEquity * 100
if riskPercent < 2 || riskPercent > 10 {
    return error // 拒绝交易
}
```

### 持仓中保护

#### 1. 强制止损
- 系统自动设置止损单
- 无法取消或修改（除非平仓）
- 触发后立即市价平仓

#### 2. 强制止盈  
- 系统自动设置止盈单
- 防止贪婪错失利润
- 触发后立即市价平仓

#### 3. 仓位监控
- 实时监控保证金使用率
- 总保证金使用率 ≤ 90%
- 最多同时持仓5个币种

---

## 🔄 交易执行流程

### 完整执行周期

```
1. 数据收集
   ├── 获取市场数据 (价格、指标、成交量)
   ├── 获取账户信息 (余额、持仓、保证金)
   └── 获取历史表现 (夏普比率、胜率)

2. AI决策生成  
   ├── 构建System Prompt (固定规则)
   ├── 构建User Prompt (动态数据)
   ├── 调用AI API
   └── 解析决策JSON

3. 决策验证
   ├── 参数合法性检查
   ├── 风险控制验证
   ├── 仓位限制检查
   └── 止损止盈验证

4. 决策执行
   ├── 按优先级排序 (平仓 > 开仓)
   ├── 逐个执行决策
   ├── 设置止损止盈
   └── 记录执行日志

5. 结果记录
   ├── 保存完整决策记录
   ├── 更新持仓状态
   ├── 计算性能指标
   └── 准备下一周期
```

### 执行优先级

1. **平仓操作** (`close_long`, `close_short`) - 最高优先级
2. **开仓操作** (`open_long`, `open_short`) - 中等优先级  
3. **持仓操作** (`hold`) - 低优先级
4. **观望操作** (`wait`) - 最低优先级

### 错误处理

#### 开仓失败处理
- 记录错误原因
- 不影响其他决策执行
- 在下一周期重新评估

#### 平仓失败处理
- 立即重试
- 记录警告日志
- 保持止损止盈单有效

#### 止损止盈设置失败
- 记录警告但不阻止开仓
- 依赖交易所的强制平仓机制
- 在下一周期重新设置

---

## 📊 性能监控

### 关键指标

1. **夏普比率**: 风险调整后收益率
2. **胜率**: 盈利交易占比
3. **平均盈亏比**: 平均盈利/平均亏损
4. **最大回撤**: 最大连续亏损
5. **持仓时长**: 平均持仓时间

### 自适应机制

根据夏普比率调整策略:
- **< -0.5**: 停止交易，反思策略
- **-0.5 ~ 0**: 严格控制，降低频率
- **0 ~ 0.7**: 维持当前策略
- **> 0.7**: 可适度扩大仓位

---

## 🔧 配置参数

### 杠杆配置
```json
{
  "btc_eth_leverage": 20,    // BTC/ETH最大杠杆
  "altcoin_leverage": 10     // 山寨币最大杠杆
}
```

### 风险控制参数
- **最小止损距离**: ETH/BTC 4.5%, 其他 5.0%
- **最小风险回报比**: 2.0:1 ~ 3.0:1 (根据信心度)
- **单笔风险范围**: 2% ~ 10% 账户净值
- **最大保证金使用率**: 90%
- **最大持仓数量**: 5个币种

### 交易限制
- **最小信心度**: 75%
- **最小仓位**: 根据交易所LOT_SIZE规则
- **价格精度**: 自动适配交易所规则

---

## 🚨 注意事项

### 重要提醒

1. **风险控制优先**: 所有交易都必须通过风险验证
2. **止损必设**: 每个开仓都必须设置止损
3. **防重复开仓**: 同币种同方向不允许叠加
4. **平仓优先**: 平仓决策优先于开仓执行
5. **精度适配**: 自动处理交易所的数量和价格精度要求

### 系统限制

1. **AI无记忆**: 每次决策都是独立的，无跨会话记忆
2. **实时数据**: 基于当前市场数据，不预测未来
3. **交易所限制**: 受交易所API限制和规则约束
4. **网络延迟**: 可能存在价格滑点和执行延迟

### 最佳实践

1. **监控日志**: 定期检查决策日志和执行结果
2. **参数调优**: 根据实际表现调整风险参数
3. **资金管理**: 合理设置账户资金和杠杆
4. **风险意识**: 始终保持风险控制意识

---

*本文档描述了NOFX交易系统的核心逻辑，实际实现可能因版本更新而有所变化。*