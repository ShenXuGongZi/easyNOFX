#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
cat << "BANNER"
╔═══════════════════════════════════════════╗
║     NOFX 强制更新脚本（已修复）          ║
╚═══════════════════════════════════════════╝
BANNER
echo -e "${NC}\n"

PROJECT_DIR="/root/nofx"
BACKUP_BASE="/root/nofx_backups"
WEB_DEPLOY_DIR="/var/www/nofx"

cd "$PROJECT_DIR"

# ============================================
# 步骤 1: 备份 config.json
# ============================================
echo -e "${YELLOW}💾 步骤 1: 备份 config.json...${NC}\n"

CONFIG_BACKUP="/tmp/config.json.safe_backup_$(date +%s)"

if [ -f "config.json" ]; then
    cp config.json "$CONFIG_BACKUP"
    echo -e "${GREEN}✅ config.json 已备份到: $CONFIG_BACKUP${NC}"
    echo -e "${BLUE}📄 MD5: $(md5sum config.json | awk '{print $1}')${NC}\n"
else
    if [ -f "/tmp/nofx_config.json.protected" ]; then
        cp /tmp/nofx_config.json.protected "$CONFIG_BACKUP"
        echo -e "${GREEN}✅ 从临时位置备份了 config.json${NC}\n"
    else
        LATEST_BACKUP=$(ls -dt $BACKUP_BASE/backup_* 2>/dev/null | head -1)
        if [ -n "$LATEST_BACKUP" ] && [ -f "$LATEST_BACKUP/config.json" ]; then
            cp "$LATEST_BACKUP/config.json" "$CONFIG_BACKUP"
            echo -e "${GREEN}✅ 从备份恢复了 config.json${NC}\n"
        else
            echo -e "${RED}❌ 找不到 config.json！${NC}"
            exit 1
        fi
    fi
fi

# ============================================
# 步骤 2: 强制重置 Git
# ============================================
echo -e "${YELLOW}🔄 步骤 2: 强制重置到远程版本...${NC}\n"

git fetch origin

echo -e "${BLUE}即将重置的文件:${NC}"
git diff --name-only HEAD origin/main | sed 's/^/  • /' || echo "  (无差异)"
echo ""

git reset --hard origin/main

echo -e "${GREEN}✅ 已重置到最新版本: $(git rev-parse --short HEAD)${NC}\n"

# ============================================
# 步骤 3: 恢复 config.json
# ============================================
echo -e "${YELLOW}🔓 步骤 3: 恢复 config.json...${NC}\n"

cp "$CONFIG_BACKUP" ./config.json

echo -e "${GREEN}✅ config.json 已恢复${NC}"
echo -e "${BLUE}📄 MD5: $(md5sum config.json | awk '{print $1}')${NC}\n"

rm -f /tmp/nofx_* 2>/dev/null || true

# ============================================
# 步骤 4: 更新依赖
# ============================================
echo -e "${YELLOW}📦 步骤 4: 更新 Go 依赖...${NC}\n"

go clean -cache -modcache 2>/dev/null || true

echo -e "${BLUE}下载依赖...${NC}"
if go mod download; then
    echo -e "${GREEN}✅ 依赖下载成功${NC}\n"
else
    echo -e "${RED}❌ 依赖下载失败${NC}\n"
    exit 1
fi

echo -e "${BLUE}整理依赖...${NC}"
if go mod tidy; then
    echo -e "${GREEN}✅ 依赖整理成功${NC}\n"
else
    echo -e "${YELLOW}⚠️  依赖整理有警告（可能不影响编译）${NC}\n"
fi

# ============================================
# 步骤 5: 构建 Web 前端
# ============================================
echo -e "${YELLOW}🌐 步骤 5: 构建 Web 前端...${NC}\n"

if [ -d "web" ]; then
    cd web
    
    # 检查 Node.js 环境
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js 未安装，跳过前端构建${NC}\n"
        cd "$PROJECT_DIR"
    elif ! command -v npm &> /dev/null; then
        echo -e "${RED}❌ npm 未安装，跳过前端构建${NC}\n"
        cd "$PROJECT_DIR"
    else
        echo -e "${BLUE}Node 版本: $(node --version)${NC}"
        echo -e "${BLUE}npm 版本: $(npm --version)${NC}\n"
        
        # 安装依赖
        echo -e "${BLUE}安装前端依赖...${NC}"
        if npm install; then
            echo -e "${GREEN}✅ 前端依赖安装成功${NC}\n"
        else
            echo -e "${RED}❌ 前端依赖安装失败${NC}\n"
            cd "$PROJECT_DIR"
        fi
        
        # 构建前端
        echo -e "${BLUE}构建前端项目...${NC}"
        BUILD_START=$(date +%s)
        
        if npm run build; then
            BUILD_END=$(date +%s)
            BUILD_TIME=$((BUILD_END - BUILD_START))
            
            echo -e "\n${GREEN}✅ 前端构建成功（耗时 ${BUILD_TIME}s）${NC}\n"
            
            if [ -d "dist" ]; then
                echo -e "${BLUE}构建产物:${NC}"
                ls -lh dist/ | head -10
                echo ""
                
                # 部署到 /var/www/nofx
                if [ -n "$WEB_DEPLOY_DIR" ]; then
                    echo -e "${BLUE}部署前端到 $WEB_DEPLOY_DIR...${NC}"
                    
                    # 备份旧版本
                    if [ -d "$WEB_DEPLOY_DIR" ] && [ "$(ls -A $WEB_DEPLOY_DIR 2>/dev/null)" ]; then
                        WEB_BACKUP="$WEB_DEPLOY_DIR.backup_$(date +%s)"
                        cp -r "$WEB_DEPLOY_DIR" "$WEB_BACKUP"
                        echo -e "${BLUE}ℹ️  旧版本已备份到: $WEB_BACKUP${NC}"
                    fi
                    
                    # 创建目录
                    mkdir -p "$WEB_DEPLOY_DIR"
                    
                    # 同步文件
                    if command -v rsync &> /dev/null; then
                        rsync -av --delete dist/ "$WEB_DEPLOY_DIR/"
                    else
                        rm -rf "$WEB_DEPLOY_DIR"/*
                        cp -r dist/* "$WEB_DEPLOY_DIR"/
                    fi
                    
                    # 设置权限
                    chmod -R 755 "$WEB_DEPLOY_DIR"
                    
                    # 尝试设置 Web 服务器用户权限
                    if id "www-data" &>/dev/null; then
                        chown -R www-data:www-data "$WEB_DEPLOY_DIR" 2>/dev/null || true
                    elif id "nginx" &>/dev/null; then
                        chown -R nginx:nginx "$WEB_DEPLOY_DIR" 2>/dev/null || true
                    fi
                    
                    echo -e "${GREEN}✅ 前端已部署到 $WEB_DEPLOY_DIR${NC}\n"
                fi
            else
                echo -e "${YELLOW}⚠️  警告: dist 目录不存在${NC}\n"
            fi
        else
            echo -e "${RED}❌ 前端构建失败${NC}\n"
        fi
        
        cd "$PROJECT_DIR"
    fi
else
    echo -e "${YELLOW}⚠️  web 目录不存在，跳过前端构建${NC}\n"
fi

# ============================================
# 步骤 6: 编译后端项目（修复路径）
# ============================================
echo -e "${YELLOW}🔧 步骤 6: 编译后端项目...${NC}\n"

# 停止服务
echo -e "${BLUE}停止现有服务...${NC}"
systemctl stop nofx 2>/dev/null || pkill -9 nofx 2>/dev/null || true
sleep 3

# 备份旧版本
if [ -f "nofx" ]; then
    cp nofx nofx.pre-update
    echo -e "${BLUE}ℹ️  旧版本已备份为 nofx.pre-update${NC}\n"
fi

# 检查主程序文件是否存在
if [ ! -f "main.go" ]; then
    echo -e "${RED}❌ 错误: main.go 不存在！${NC}"
    echo -e "${YELLOW}当前目录内容:${NC}"
    ls -la
    exit 1
fi

# 编译（正确的路径：main.go）
echo -e "${BLUE}开始编译后端...${NC}"
BUILD_START=$(date +%s)

if CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o nofx main.go; then
    BUILD_END=$(date +%s)
    BUILD_TIME=$((BUILD_END - BUILD_START))
    
    echo -e "\n${GREEN}✅ 后端编译成功（耗时 ${BUILD_TIME}s）${NC}\n"
    chmod +x nofx
    
    echo -e "${BLUE}可执行文件信息:${NC}"
    ls -lh nofx
    file nofx
    echo ""
else
    echo -e "\n${RED}❌ 后端编译失败${NC}"
    echo -e "\n${YELLOW}尝试诊断...${NC}"
    echo -e "${BLUE}Go 版本:${NC}"
    go version
    echo -e "\n${BLUE}项目结构:${NC}"
    ls -la
    exit 1
fi

# ============================================
# 步骤 7: 启动服务
# ============================================
echo -e "${YELLOW}🚀 步骤 7: 启动服务...${NC}\n"

systemctl start nofx
sleep 5

if systemctl is-active --quiet nofx; then
    echo -e "${GREEN}✅ 服务已成功启动${NC}\n"
    systemctl status nofx --no-pager --lines=15
else
    echo -e "${RED}❌ 服务启动失败${NC}\n"
    echo -e "${YELLOW}最近日志:${NC}"
    journalctl -u nofx -n 50 --no-pager
    exit 1
fi

# ============================================
# 步骤 8: 验证系统
# ============================================
echo -e "\n${YELLOW}✅ 步骤 8: 验证系统...${NC}\n"

sleep 3

if command -v curl &> /dev/null; then
    echo -e "${BLUE}测试 API 连接...${NC}"
    
    API_URL="https://你的域名/api/status?trader_id=my_trader"
    
    if curl -s -f "$API_URL" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ API 正常响应${NC}\n"
        
        if command -v jq &> /dev/null; then
            echo -e "${BLUE}API 状态详情:${NC}"
            curl -s "$API_URL" | jq .
        else
            echo -e "${BLUE}API 原始响应:${NC}"
            curl -s "$API_URL"
        fi
    else
        echo -e "${YELLOW}⚠️  API 暂时无响应（服务可能还在初始化）${NC}"
        echo -e "${BLUE}提示: 等待 2-3 分钟后访问 https://你的域名${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}测试 Web 前端...${NC}"
    
    WEB_URL="https://你的域名"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WEB_URL")
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ Web 前端正常 (HTTP $HTTP_CODE)${NC}"
    else
        echo -e "${YELLOW}⚠️  Web 前端响应异常 (HTTP $HTTP_CODE)${NC}"
    fi
fi

# ============================================
# 完成总结
# ============================================
echo -e "\n${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}✅ 更新成功完成！${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BOLD}📌 更新信息:${NC}"
echo "  🔄 Git 版本: $(git rev-parse --short HEAD)"
echo "  🔖 Git 分支: $(git rev-parse --abbrev-ref HEAD)"
echo "  📅 更新时间: $(date)"
echo "  🔒 config.json: 已保护并恢复"
echo "  💾 安全备份: $CONFIG_BACKUP"
if [ -d "$WEB_DEPLOY_DIR" ]; then
    echo "  🌐 Web 前端: 已部署到 $WEB_DEPLOY_DIR"
fi
echo ""
echo -e "${BOLD}🔍 验证命令:${NC}"
echo "  • 查看状态: systemctl status nofx"
echo "  • 查看日志: journalctl -u nofx -f"
echo "  • 测试 API: curl https://你的域名/api/status?trader_id=my_trader"
if [ -d "$WEB_DEPLOY_DIR" ]; then
    echo "  • 查看前端: ls -lh $WEB_DEPLOY_DIR"
fi
echo ""
echo -e "${BOLD}🌐 访问地址:${NC}"
echo "  • Web 界面: https://你的域名"
echo "  • API 接口: https://你的域名/api/"
echo ""
echo -e "${BOLD}📋 提醒:${NC}"
echo "  • config.json 已保护，API 密钥安全"
echo "  • 如需回滚配置: cp $CONFIG_BACKUP /root/nofx/config.json"
echo "  • 旧程序备份: /root/nofx/nofx.pre-update"
if [ -d "$WEB_DEPLOY_DIR.backup_"* ] 2>/dev/null; then
    LATEST_WEB_BACKUP=$(ls -dt "$WEB_DEPLOY_DIR.backup_"* 2>/dev/null | head -1)
    if [ -n "$LATEST_WEB_BACKUP" ]; then
        echo "  • 旧前端备份: $LATEST_WEB_BACKUP"
    fi
fi
echo ""
echo -e "${BOLD}💡 如果浏览器显示旧版本:${NC}"
echo "  • 按 Ctrl + Shift + R 强制刷新"
echo "  • 或清除浏览器缓存"
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "$CONFIG_BACKUP" > /tmp/nofx_last_config_backup
