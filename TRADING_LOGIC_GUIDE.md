# NOFX 决策引擎逻辑说明 (decision/engine.go)

源项目地址：[https://github.com/tinkle-community/nofx](https://github.com/tinkle-community/nofx)

## 📋 目录

1. [决策引擎概览](#决策引擎概览)
2. [开单验证逻辑](#开单验证逻辑)
3. [止损距离验证](#止损距离验证)
4. [止盈止损设置](#止盈止损设置)
5. [风险计算机制](#风险计算机制)
6. [平仓决策逻辑](#平仓决策逻辑)
7. [AI提示词生成](#AI提示词生成)

---

## 🏗️ 决策引擎概览

`decision/engine.go` 是NOFX交易系统的核心决策引擎，负责：

- **AI决策生成**: 构建提示词，调用AI API
- **决策验证**: 验证AI生成的交易决策是否符合风险控制规则
- **参数校验**: 检查开仓参数的合法性和安全性
- **风险计算**: 计算实际交易风险并进行控制

### 核心数据结构

```go
// Decision AI的交易决策
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

## 📈 开单验证逻辑

### 1. 基础参数验证

```go
func validateDecision(d *Decision, ctx *Context) error {
    // 1. 验证交易动作的合法性
    validActions := map[string]bool{
        "open_long": true, "open_short": true,
        "close_long": true, "close_short": true,
        "hold": true, "wait": true,
    }
    
    // 2. 开仓操作的完整性检查
    if d.Action == "open_long" || d.Action == "open_short" {
        // 获取实时市场价格
        marketData := ctx.MarketDataMap[d.Symbol]
        currentPrice := marketData.CurrentPrice
        
        // 验证必填参数
        if d.Leverage <= 0 || d.PositionSizeUSD <= 0 {
            return fmt.Errorf("杠杆和仓位大小必须大于0")
        }
        if d.StopLoss <= 0 || d.TakeProfit <= 0 {
            return fmt.Errorf("止损和止盈必须大于0")
        }
    }
}
```

### 2. 杠杆限制验证

```go
// 根据币种类型设置不同的杠杆上限
maxLeverage := ctx.AltcoinLeverage // 山寨币默认10倍
if d.Symbol == "BTCUSDT" || d.Symbol == "ETHUSDT" {
    maxLeverage = ctx.BTCETHLeverage // BTC/ETH可达20倍
}

if d.Leverage > maxLeverage {
    return fmt.Errorf("杠杆超出限制: %d > %d", d.Leverage, maxLeverage)
}
```

### 3. 仓位大小限制

```go
// 防止单个仓位过度集中风险
maxSinglePosition := ctx.Account.TotalEquity * 20 // 最多20倍账户净值
if d.PositionSizeUSD > maxSinglePosition {
    return fmt.Errorf("单个仓位过大，超出风险限制")
}
```

---

## 🎯 止损距离验证

### 1. 智能容错机制

```go
func getMinStopLossDistance(symbol string) float64 {
    // 主流币种享受智能容错
    if symbol == "ETHUSDT" || symbol == "BTCUSDT" {
        return 0.045 // 4.5%
    }
    // 其他币种保持标准要求
    return 0.05 // 5.0%
}
```

### 2. 止损距离计算与验证

```go
// 做多止损距离验证
if d.Action == "open_long" {
    actualDistance := (currentPrice - d.StopLoss) / currentPrice
    
    // 浮点精度容差处理 (修复精度问题)
    tolerance := 0.0001 // 0.01%容差
    if actualDistance < (minStopLossDistance - tolerance) {
        requiredStopLoss := currentPrice * (1 - minStopLossDistance)
        return fmt.Errorf("做多止损价 %.6f 距离当前市价 %.6f 太近，至少需要%.1f%%安全距离，建议止损价≤%.6f", 
            d.StopLoss, currentPrice, minStopLossDistance*100, requiredStopLoss)
    }
}

// 做空止损距离验证
if d.Action == "open_short" {
    actualDistance := (d.StopLoss - currentPrice) / currentPrice
    
    tolerance := 0.0001 // 0.01%容差
    if actualDistance < (minStopLossDistance - tolerance) {
        requiredStopLoss := currentPrice * (1 + minStopLossDistance)
        return fmt.Errorf("做空止损价 %.6f 距离当前市价 %.6f 太近，至少需要%.1f%%安全距离，建议止损价≥%.6f", 
            d.StopLoss, currentPrice, minStopLossDistance*100, requiredStopLoss)
    }
}
```

### 3. 止损止盈合理性检查

```go
// 做多: 止损 < 当前价 < 止盈
if d.Action == "open_long" {
    if d.StopLoss >= d.TakeProfit {
        return fmt.Errorf("做多时止损价必须小于止盈价")
    }
}

// 做空: 止盈 < 当前价 < 止损  
if d.Action == "open_short" {
    if d.StopLoss <= d.TakeProfit {
        return fmt.Errorf("做空时止损价必须大于止盈价")
    }
}
```

---

## 💰 风险计算机制

### 1. 风险回报比验证

```go
// 根据信心度动态调整风险回报比要求
var minRiskRewardRatio float64
if d.Confidence >= 85 {
    minRiskRewardRatio = 3.0    // 高信心度要求3.0:1
} else if d.Confidence >= 80 {
    minRiskRewardRatio = 2.5    // 中等信心度要求2.5:1
} else {
    minRiskRewardRatio = 2.0    // 低信心度要求2.0:1
}

// 计算实际风险回报比
var riskRewardRatio float64
if d.Action == "open_long" {
    riskDistance := currentPrice - d.StopLoss
    rewardDistance := d.TakeProfit - currentPrice
    riskRewardRatio = rewardDistance / riskDistance
} else {
    riskDistance := d.StopLoss - currentPrice
    rewardDistance := currentPrice - d.TakeProfit
    riskRewardRatio = rewardDistance / riskDistance
}

// 验证是否满足要求
if riskRewardRatio < minRiskRewardRatio {
    return fmt.Errorf("风险回报比过低(%.2f:1)，要求≥%.1f:1", 
        riskRewardRatio, minRiskRewardRatio)
}
```

### 2. 账户风险百分比计算

```go
var riskPercent float64

// 优先使用AI提供的RiskUSD（更准确）
if d.RiskUSD > 0 && d.PositionSizeUSD > 0 {
    riskPercent = d.RiskUSD / ctx.Account.TotalEquity * 100
} else {
    // 备用计算：仓位价值 × 止损距离百分比
    var stopLossDistancePercent float64
    if d.Action == "open_long" {
        stopLossDistancePercent = (currentPrice - d.StopLoss) / currentPrice
    } else {
        stopLossDistancePercent = (d.StopLoss - currentPrice) / currentPrice
    }
    
    // 正确的风险计算公式 (已修复杠杆乘法bug)
    actualRiskUSD := d.PositionSizeUSD * stopLossDistancePercent
    riskPercent = actualRiskUSD / ctx.Account.TotalEquity * 100
}

// 风险范围验证
if riskPercent < 2.0 || riskPercent > 10.0 {
    return fmt.Errorf("单笔风险超出范围(%.2f%%)，必须在2-10%%之间", riskPercent)
}

// 高风险操作需要极高信心度
if riskPercent > 8.0 && d.Confidence < 90 {
    return fmt.Errorf("高风险操作(%.2f%%)需要极高信心度(≥90)，当前: %d", 
        riskPercent, d.Confidence)
}
```

### 3. 信心度门槛验证

```go
// 硬约束：信心度必须≥75才能开单
if d.Confidence < 75 {
    return fmt.Errorf("信心度过低(%d%%)，必须≥75%% 才能开单", d.Confidence)
}
```

---

## 📉 平仓决策逻辑

### 1. 平仓操作验证

```go
// 平仓操作相对简单，主要验证动作的合法性
if d.Action == "close_long" || d.Action == "close_short" {
    // 平仓不需要复杂的参数验证
    // 主要由交易执行器检查是否存在对应持仓
    return nil
}
```

### 2. 持仓状态检查

平仓的具体逻辑主要在交易执行器中实现，决策引擎只负责验证决策的合法性。实际的持仓检查和平仓执行由 `trader/auto_trader.go` 处理。

---

## 🤖 AI提示词生成

### 1. System Prompt 构建

```go
func buildSystemPrompt(accountEquity float64, btcEthLeverage, altcoinLeverage int) string {
    var sb strings.Builder
    
    // 角色定义
    sb.WriteString("你是专业的加密货币交易AI...\n")
    
    // 风险控制规则
    sb.WriteString("# ⚖️ 硬约束（风险控制）\n")
    sb.WriteString("1. **动态风险回报比**（根据信心度调整）:\n")
    sb.WriteString("   - 高信心度(≥85%): 最低 1:3.0\n")
    sb.WriteString("   - 中等信心度(80-84%): 最低 1:2.5\n")
    sb.WriteString("   - 低信心度(75-79%): 最低 1:2.0\n")
    
    // 杠杆使用指导
    sb.WriteString("   📋 **杠杆使用指导**：\n")
    sb.WriteString("     • 高信心度(≥85%): 建议5-10倍杠杆\n")
    sb.WriteString("     • 中等信心度(80-84%): 建议3-7倍杠杆\n")
    sb.WriteString("     • 低信心度(75-79%): 建议2-5倍杠杆\n")
    
    // 止损距离要求
    sb.WriteString("**止损距离验证**：\n")
    sb.WriteString("   • ETH/BTC：最小4.5%，其他币种：最小5.0%\n")
    sb.WriteString("   • 系统验证极其严格，建议预留0.1-0.2%缓冲\n")
    
    return sb.String()
}
```

### 2. User Prompt 构建

```go
func buildUserPrompt(ctx *Context) string {
    var sb strings.Builder
    
    // 系统状态
    sb.WriteString(fmt.Sprintf("**时间**: %s | **周期**: #%d\n", 
        ctx.CurrentTime, ctx.CallCount))
    
    // 账户信息
    sb.WriteString(fmt.Sprintf("**账户**: 净值%.2f | 余额%.2f\n", 
        ctx.Account.TotalEquity, ctx.Account.AvailableBalance))
    
    // 当前持仓
    if len(ctx.Positions) > 0 {
        sb.WriteString("## 当前持仓\n")
        for _, pos := range ctx.Positions {
            sb.WriteString(fmt.Sprintf("%s %s | 盈亏%+.2f%%\n", 
                pos.Symbol, pos.Side, pos.UnrealizedPnLPct))
        }
    }
    
    // 候选币种市场数据
    sb.WriteString("## 候选币种\n")
    for _, coin := range ctx.CandidateCoins {
        if marketData, ok := ctx.MarketDataMap[coin.Symbol]; ok {
            sb.WriteString(market.Format(marketData))
        }
    }
    
    return sb.String()
}
```

---

## 🔄 决策处理流程

### 1. 完整决策流程

```go
func GetFullDecision(ctx *Context, aiClient *mcp.Client) (*FullDecision, error) {
    // 1. 获取市场数据
    if err := fetchMarketDataForContext(ctx); err != nil {
        return nil, fmt.Errorf("获取市场数据失败: %w", err)
    }
    
    // 2. 构建AI提示词
    systemPrompt := buildSystemPrompt(ctx.Account.TotalEquity, ctx.BTCETHLeverage, ctx.AltcoinLeverage)
    userPrompt := buildUserPrompt(ctx)
    
    // 3. 调用AI API
    aiResponse, err := aiClient.CallWithMessages(systemPrompt, userPrompt)
    if err != nil {
        return nil, fmt.Errorf("调用AI API失败: %w", err)
    }
    
    // 4. 解析AI响应
    decision, err := parseFullDecisionResponse(aiResponse, ctx)
    if err != nil {
        return nil, fmt.Errorf("解析AI响应失败: %w", err)
    }
    
    return decision, nil
}
```

### 2. AI响应解析

```go
func parseFullDecisionResponse(aiResponse string, ctx *Context) (*FullDecision, error) {
    // 1. 提取思维链分析
    cotTrace := extractCoTTrace(aiResponse)
    
    // 2. 提取JSON决策数组
    decisions, err := extractDecisions(aiResponse)
    if err != nil {
        return nil, fmt.Errorf("提取决策失败: %w", err)
    }
    
    // 3. 验证所有决策
    if err := validateDecisions(decisions, ctx); err != nil {
        return nil, fmt.Errorf("决策验证失败: %w", err)
    }
    
    return &FullDecision{
        CoTTrace:  cotTrace,
        Decisions: decisions,
    }, nil
}
```

### 3. 批量决策验证

```go
func validateDecisions(decisions []Decision, ctx *Context) error {
    // 1. 基础验证：账户净值检查
    if ctx.Account.TotalEquity <= 0 {
        return fmt.Errorf("账户净值异常")
    }
    
    // 2. 风险控制：最多5个开仓操作
    openPositionCount := 0
    for _, decision := range decisions {
        if decision.Action == "open_long" || decision.Action == "open_short" {
            openPositionCount++
        }
    }
    if openPositionCount > 5 {
        return fmt.Errorf("违反风险控制：最多只能开5个仓位")
    }
    
    // 3. 逐个验证每个决策
    for i, decision := range decisions {
        if err := validateDecision(&decision, ctx); err != nil {
            return fmt.Errorf("决策 #%d 验证失败: %w", i+1, err)
        }
    }
    
    return nil
}
```

---

## 🚨 关键验证规则总结

### 开仓必须满足的条件

1. **基础参数**: 杠杆、仓位、止损、止盈都必须 > 0
2. **杠杆限制**: BTC/ETH ≤ 20倍，山寨币 ≤ 10倍
3. **止损距离**: ETH/BTC ≥ 4.5%，其他币种 ≥ 5.0%
4. **风险回报比**: 根据信心度要求2.0-3.0:1
5. **账户风险**: 单笔风险控制在2-10%范围内
6. **信心度门槛**: 必须 ≥ 75%才能开单
7. **仓位限制**: 单个仓位不超过账户净值20倍
8. **数量限制**: 最多同时开5个新仓位

### 平仓相对简单

- 主要验证动作合法性
- 具体执行由交易器处理
- 不需要复杂的风险计算

### 浮点精度处理

- 增加0.01%容差避免精度问题
- 5.00%的止损距离可以通过验证
- 4.99%仍然会被拒绝

---

*本文档专门描述了 `decision/engine.go` 文件中的核心决策逻辑，包括开单验证、止损止盈设置、风险计算和平仓处理的具体实现。*

