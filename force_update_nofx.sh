#!/bin/bash

# ================================================================
# NOFX AI 交易机器人 - 一键强制更新脚本
# ================================================================
# 作者: 375.btc (行雲) | Twitter: @hangzai
# 适配版本: Docker Compose 部署方式
# 更新日期: 2025-10
# ================================================================

set -euo pipefail

# ================================
# 颜色定义
# ================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ================================
# 全局变量
# ================================
PROJECT_DIR="/opt/nofx"
BACKUP_DIR="/opt/nofx_backups"
UPDATE_LOG="/var/log/nofx_update.log"
NOFX_USER="nofx"
YOUR_DOMAIN=""  # 用户可以修改的域名变量

# ================================
# 检查 root 权限
# ================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ 此脚本需要使用 root 用户运行！${NC}"
        echo -e "${YELLOW}请使用以下命令：${NC}"
        echo -e "  sudo bash $0"
        exit 1
    fi
}

# ================================
# 打印横幅
# ================================
print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << "BANNER"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     🚀 NOFX AI 交易机器人 - 强制更新脚本（Docker 版本）         ║
║                                                               ║
║        作者: 375.btc (行雲)  |  Twitter: @hangzai              ║
║        项目: https://github.com/ShenXuGongZi/easyNOFX         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}\n"
}

# ================================
# 日志函数
# ================================
log_message() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$UPDATE_LOG"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$UPDATE_LOG"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$UPDATE_LOG"
}

log_info() {
    echo -e "${CYAN}[ℹ]${NC} $1" | tee -a "$UPDATE_LOG"
}

log_step() {
    echo "" | tee -a "$UPDATE_LOG"
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$UPDATE_LOG"
    echo -e "${PURPLE}${BOLD}▶ $1${NC}" | tee -a "$UPDATE_LOG"
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$UPDATE_LOG"
    echo "" | tee -a "$UPDATE_LOG"
}

# ================================
# 环境检查
# ================================
check_environment() {
    log_step "步骤 0: 环境检查"
    
    # 检查项目目录
    if [[ ! -d "$PROJECT_DIR" ]]; then
        log_error "NOFX 项目目录不存在: $PROJECT_DIR"
        log_info "请先运行安装脚本"
        exit 1
    fi
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        exit 1
    fi
    
    # 检查 Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose 未安装"
        exit 1
    fi
    
    # 检查 Git
    if ! command -v git &> /dev/null; then
        log_error "Git 未安装"
        exit 1
    fi
    
    log_message "环境检查通过 ✓"
    
    # 显示当前版本信息
    cd "$PROJECT_DIR"
    
    if [[ -d .git ]]; then
        local current_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "未知")
        local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "未知")
        
        log_info "当前版本: $current_commit ($current_branch)"
    fi
    
    # 显示服务状态
    log_info "当前服务状态:"
    docker compose ps 2>/dev/null | tee -a "$UPDATE_LOG" || true
}

# ================================
# 步骤 1: 备份配置文件
# ================================
backup_config() {
    log_step "步骤 1: 备份配置文件"
    
    cd "$PROJECT_DIR"
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 生成备份文件名（时间戳）
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local config_backup="$BACKUP_DIR/config_${timestamp}.json"
    local full_backup="$BACKUP_DIR/backup_${timestamp}"
    
    # 备份 config.json
    if [[ -f "config.json" ]]; then
        cp config.json "$config_backup"
        log_message "配置文件已备份: $config_backup"
        
        # 显示 MD5 校验
        local md5_sum=$(md5sum config.json | awk '{print $1}')
        log_info "配置文件 MD5: $md5_sum"
        
        # 额外保存到临时位置（双重保险）
        cp config.json "/tmp/nofx_config_safe_backup_${timestamp}.json"
    else
        log_warning "config.json 不存在，尝试从备份恢复..."
        
        # 查找最新备份
        local latest_backup=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -1)
        
        if [[ -n "$latest_backup" ]]; then
            cp "$latest_backup" config.json
            log_message "已从备份恢复配置: $latest_backup"
        else
            log_error "找不到任何配置备份！"
            exit 1
        fi
    fi
    
    # 完整备份（包括决策日志等）
    log_info "创建完整备份..."
    mkdir -p "$full_backup"
    
    # 备份重要文件和目录
    [[ -f config.json ]] && cp config.json "$full_backup/"
    [[ -d decision_logs ]] && cp -r decision_logs "$full_backup/" 2>/dev/null || true
    [[ -d coin_pool_cache ]] && cp -r coin_pool_cache "$full_backup/" 2>/dev/null || true
    [[ -f docker-compose.yml ]] && cp docker-compose.yml "$full_backup/"
    
    log_message "完整备份已创建: $full_backup"
    
    # 保存备份路径到环境变量（供后续步骤使用）
    export NOFX_CONFIG_BACKUP="$config_backup"
    export NOFX_FULL_BACKUP="$full_backup"
    
    # 清理旧备份（保留最近 10 个）
    log_info "清理旧备份（保留最近 10 个）..."
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +11 | xargs -r rm -f
    ls -dt "$BACKUP_DIR"/backup_* 2>/dev/null | tail -n +11 | xargs -r rm -rf
    
    log_message "配置备份完成 ✓"
}

# ================================
# 步骤 2: 停止服务
# ================================
stop_services() {
    log_step "步骤 2: 停止 Docker 服务"
    
    cd "$PROJECT_DIR"
    
    # 检查是否有运行的容器
    if docker compose ps 2>/dev/null | grep -q "Up"; then
        log_info "正在停止 Docker 容器..."
        
        # 优雅停止（30秒超时）
        if docker compose stop -t 30 >> "$UPDATE_LOG" 2>&1; then
            log_message "容器已停止 ✓"
        else
            log_warning "优雅停止失败，强制停止..."
            docker compose kill >> "$UPDATE_LOG" 2>&1 || true
        fi
        
        sleep 2
    else
        log_info "没有运行中的容器"
    fi
    
    # 显示容器状态
    log_info "当前容器状态:"
    docker compose ps 2>/dev/null | tee -a "$UPDATE_LOG" || true
}

# ================================
# 步骤 3: 强制更新代码
# ================================
update_code() {
    log_step "步骤 3: 强制更新代码"
    
    cd "$PROJECT_DIR"
    
    # 显示当前状态
    log_info "当前 Git 状态:"
    git status --short | tee -a "$UPDATE_LOG" || true
    
    # 获取远程更新
    log_info "获取远程更新..."
    if git fetch origin >> "$UPDATE_LOG" 2>&1; then
        log_message "远程更新获取成功 ✓"
    else
        log_error "无法获取远程更新"
        log_info "请检查网络连接"
        exit 1
    fi
    
    # 显示即将更新的文件
    log_info "即将更新的文件:"
    git diff --name-only HEAD origin/main | sed 's/^/  • /' | tee -a "$UPDATE_LOG" || echo "  (无差异)"
    
    # 询问是否继续
    echo ""
    read -p "确认强制更新到最新版本？(y/n): " confirm
    
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        log_warning "更新已取消"
        exit 0
    fi
    
    # 强制重置到远程版本
    log_info "强制重置到远程版本..."
    
    if git reset --hard origin/main >> "$UPDATE_LOG" 2>&1; then
        local new_commit=$(git rev-parse --short HEAD)
        log_message "代码已更新到: $new_commit ✓"
    else
        log_error "代码更新失败"
        exit 1
    fi
    
    # 清理未跟踪的文件（可选）
    read -p "是否清理未跟踪的文件？(y/n): " clean_untracked
    
    if [[ $clean_untracked == "y" || $clean_untracked == "Y" ]]; then
        git clean -fd >> "$UPDATE_LOG" 2>&1
        log_message "未跟踪文件已清理 ✓"
    fi
}

# ================================
# 步骤 4: 恢复配置文件
# ================================
restore_config() {
    log_step "步骤 4: 恢复配置文件"
    
    cd "$PROJECT_DIR"
    
    if [[ -z "$NOFX_CONFIG_BACKUP" ]] || [[ ! -f "$NOFX_CONFIG_BACKUP" ]]; then
        log_error "配置备份文件不存在"
        exit 1
    fi
    
    # 恢复配置
    cp "$NOFX_CONFIG_BACKUP" ./config.json
    
    # 验证恢复
    local restored_md5=$(md5sum config.json | awk '{print $1}')
    local backup_md5=$(md5sum "$NOFX_CONFIG_BACKUP" | awk '{print $1}')
    
    if [[ "$restored_md5" == "$backup_md5" ]]; then
        log_message "配置文件已恢复 ✓"
        log_info "MD5 校验: $restored_md5"
    else
        log_error "配置恢复验证失败！"
        exit 1
    fi
    
    # 设置正确的权限
    chown $NOFX_USER:$NOFX_USER config.json
    chmod 600 config.json
    
    log_message "配置权限已设置 ✓"
}

# ================================
# 步骤 5: 重新构建 Docker 镜像
# ================================
rebuild_docker() {
    log_step "步骤 5: 重新构建 Docker 镜像"
    
    cd "$PROJECT_DIR"
    
    log_info "清理旧镜像和容器..."
    
    # 删除旧容器
    docker compose down --remove-orphans >> "$UPDATE_LOG" 2>&1 || true
    
    # 可选：删除旧镜像（节省空间）
    read -p "是否删除旧的 Docker 镜像？(建议选 y) (y/n): " remove_old_images
    
    if [[ $remove_old_images == "y" || $remove_old_images == "Y" ]]; then
        log_info "删除旧镜像..."
        docker compose down --rmi all --volumes >> "$UPDATE_LOG" 2>&1 || true
        
        # 清理未使用的镜像
        docker image prune -f >> "$UPDATE_LOG" 2>&1 || true
        log_message "旧镜像已清理 ✓"
    fi
    
    # 重新构建镜像
    log_info "开始构建新镜像（可能需要几分钟）..."
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if docker compose build --no-cache 2>&1 | tee -a "$UPDATE_LOG" | grep -E "Building|Pulling|Step"; then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        log_message "Docker 镜像构建成功 ✓"
    else
        echo ""
        log_error "Docker 镜像构建失败"
        log_info "查看详细日志: $UPDATE_LOG"
        exit 1
    fi
}

# ================================
# 步骤 6: 启动服务
# ================================
start_services() {
    log_step "步骤 6: 启动服务"
    
    cd "$PROJECT_DIR"
    
    log_info "启动 Docker 容器..."
    
    if docker compose up -d >> "$UPDATE_LOG" 2>&1; then
        log_message "容器启动成功 ✓"
    else
        log_error "容器启动失败"
        log_info "查看日志: docker compose logs"
        exit 1
    fi
    
    # 等待服务启动
    log_info "等待服务完全启动（预计 10-15 秒）..."
    
    local wait_time=0
    local max_wait=30
    
    while [ $wait_time -lt $max_wait ]; do
        if docker compose ps | grep -q "Up"; then
            break
        fi
        echo -n "."
        sleep 1
        wait_time=$((wait_time + 1))
    done
    echo ""
    
    # 显示容器状态
    log_info "容器状态:"
    docker compose ps | tee -a "$UPDATE_LOG"
    echo ""
}

# ================================
# 步骤 7: 健康检查
# ================================
health_check() {
    log_step "步骤 7: 健康检查"
    
    local backend_ok=false
    local frontend_ok=false
    
    # 等待服务完全就绪
    log_info "等待服务就绪（最多 30 秒）..."
    sleep 5
    
    # 检查后端 API
    log_info "检查后端 API..."
    
    local retries=0
    local max_retries=15
    
    while [ $retries -lt $max_retries ]; do
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            log_message "后端 API 健康检查通过 ✓"
            backend_ok=true
            break
        else
            retries=$((retries + 1))
            if [ $retries -lt $max_retries ]; then
                echo -n "."
                sleep 2
            fi
        fi
    done
    echo ""
    
    if [ "$backend_ok" = false ]; then
        log_warning "后端 API 可能还在启动中"
        log_info "稍后可以运行: docker compose logs backend"
    fi
    
    # 检查前端
    log_info "检查前端服务..."
    
    retries=0
    while [ $retries -lt $max_retries ]; do
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            log_message "前端服务健康检查通过 ✓"
            frontend_ok=true
            break
        else
            retries=$((retries + 1))
            if [ $retries -lt $max_retries ]; then
                echo -n "."
                sleep 2
            fi
        fi
    done
    echo ""
    
    if [ "$frontend_ok" = false ]; then
        log_warning "前端服务可能还在启动中"
        log_info "稍后可以运行: docker compose logs frontend"
    fi
    
    # 如果用户配置了域名，测试远程访问
    if [[ -n "$YOUR_DOMAIN" ]]; then
        log_info "检查域名访问: $YOUR_DOMAIN"
        
        if curl -s -f "https://$YOUR_DOMAIN" > /dev/null 2>&1; then
            log_message "域名访问正常 ✓"
        elif curl -s -f "http://$YOUR_DOMAIN" > /dev/null 2>&1; then
            log_warning "域名可访问，但未使用 HTTPS"
            log_info "建议配置 SSL 证书"
        else
            log_warning "无法通过域名访问"
            log_info "请检查 Nginx 配置和 DNS 解析"
        fi
    fi
    
    # 显示资源使用
    log_info "容器资源使用情况:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -4 | tee -a "$UPDATE_LOG"
}

# ================================
# 步骤 8: 显示更新摘要
# ================================
show_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    clear
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}✅ 更新成功完成！${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 更新信息
    echo -e "${BOLD}📌 更新信息${NC}"
    echo ""
    
    cd "$PROJECT_DIR"
    
    local git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "未知")
    local git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "未知")
    local update_date=$(date "+%Y-%m-%d %H:%M:%S")
    
    echo -e "  🔄 Git 版本: ${GREEN}$git_commit${NC}"
    echo -e "  🔖 Git 分支: ${GREEN}$git_branch${NC}"
    echo -e "  📅 更新时间: ${GREEN}$update_date${NC}"
    echo -e "  ⏱️  总耗时: ${GREEN}${duration}秒${NC}"
    echo -e "  🔒 配置文件: ${GREEN}已保护并恢复${NC}"
    echo -e "  💾 配置备份: ${CYAN}$NOFX_CONFIG_BACKUP${NC}"
    echo -e "  📦 完整备份: ${CYAN}$NOFX_FULL_BACKUP${NC}"
    echo ""
    
    # 访问地址
    echo -e "${BOLD}🌐 访问地址${NC}"
    echo ""
    
    # 获取服务器 IP
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s api.ipify.org 2>/dev/null || echo "localhost")
    
    echo -e "  ${YELLOW}本地访问:${NC}"
    echo -e "    • Web 控制台: ${BLUE}http://localhost:3000${NC}"
    echo -e "    • API 接口:   ${BLUE}http://localhost:8080${NC}"
    echo ""
    
    if [[ "$server_ip" != "localhost" ]]; then
        echo -e "  ${YELLOW}远程访问:${NC}"
        echo -e "    • 通过 IP:    ${BLUE}http://$server_ip:3000${NC}"
        
        if [[ -n "$YOUR_DOMAIN" ]]; then
            echo -e "    • 通过域名:   ${BLUE}https://$YOUR_DOMAIN${NC}"
        else
            echo -e "    • ${CYAN}提示: 编辑脚本顶部的 YOUR_DOMAIN 变量配置域名${NC}"
        fi
    fi
    echo ""
    
    # 常用命令
    echo -e "${BOLD}🔧 常用命令${NC}"
    echo ""
    echo -e "  ${YELLOW}进入项目目录:${NC}"
    echo -e "    cd $PROJECT_DIR"
    echo ""
    echo -e "  ${YELLOW}查看服务状态:${NC}"
    echo -e "    docker compose ps"
    echo ""
    echo -e "  ${YELLOW}查看实时日志:${NC}"
    echo -e "    docker compose logs -f"
    echo -e "    docker compose logs -f backend"
    echo -e "    docker compose logs -f frontend"
    echo ""
    echo -e "  ${YELLOW}重启服务:${NC}"
    echo -e "    docker compose restart"
    echo ""
    echo -e "  ${YELLOW}停止服务:${NC}"
    echo -e "    docker compose stop"
    echo ""
    echo -e "  ${YELLOW}查看资源:${NC}"
    echo -e "    docker stats"
    echo ""
    
    # 验证命令
    echo -e "${BOLD}🔍 验证命令${NC}"
    echo ""
    echo -e "  ${YELLOW}测试 API:${NC}"
    echo -e "    curl http://localhost:8080/health"
    echo ""
    
    if [[ -n "$YOUR_DOMAIN" ]]; then
        echo -e "  ${YELLOW}测试域名:${NC}"
        echo -e "    curl https://$YOUR_DOMAIN"
        echo ""
    fi
    
    # 回滚说明
    echo -e "${BOLD}↩️  回滚说明${NC}"
    echo ""
    echo -e "  ${YELLOW}如需回滚配置:${NC}"
    echo -e "    cp $NOFX_CONFIG_BACKUP $PROJECT_DIR/config.json"
    echo -e "    cd $PROJECT_DIR && docker compose restart"
    echo ""
    echo -e "  ${YELLOW}如需完全回滚:${NC}"
    echo -e "    cd $PROJECT_DIR"
    echo -e "    git reset --hard HEAD@{1}  # 回到上一个版本"
    echo -e "    docker compose down"
    echo -e "    docker compose up -d --build"
    echo ""
    
    # 提醒事项
    echo -e "${BOLD}💡 浏览器缓存清理${NC}"
    echo ""
    echo -e "  如果浏览器显示旧版本："
    echo -e "    • 按 ${YELLOW}Ctrl + Shift + R${NC} 强制刷新"
    echo -e "    • 或清除浏览器缓存"
    echo ""
    
    # 日志位置
    echo -e "${BOLD}📋 日志文件${NC}"
    echo ""
    echo -e "  • 更新日志: ${CYAN}$UPDATE_LOG${NC}"
    echo -e "  • 查看命令: ${YELLOW}cat $UPDATE_LOG${NC}"
    echo ""
    
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 询问是否查看日志
    read -p "是否查看实时日志？(y/n): " view_logs
    
    if [[ $view_logs == "y" || $view_logs == "Y" ]]; then
        echo ""
        log_info "正在打开实时日志，按 Ctrl+C 退出..."
        sleep 2
        cd "$PROJECT_DIR"
        docker compose logs -f
    else
        echo ""
        echo -e "${GREEN}${BOLD}✨ 更新完成，感谢使用 NOFX！${NC}"
        echo -e "${CYAN}作者: 375.btc (行雲) | Twitter: @hangzai${NC}"
        echo ""
    fi
}

# ================================
# 错误处理
# ================================
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    echo "" | tee -a "$UPDATE_LOG"
    log_error "更新过程中发生错误！(退出代码: $exit_code, 行号: $line_number)"
    echo "" | tee -a "$UPDATE_LOG"
    
    log_warning "错误排查建议："
    echo -e "  1. 查看更新日志: ${CYAN}cat $UPDATE_LOG${NC}"
    echo -e "  2. 查看容器日志: ${CYAN}cd $PROJECT_DIR && docker compose logs${NC}"
    echo -e "  3. 检查网络连接: ${CYAN}ping github.com${NC}"
    echo -e "  4. 检查磁盘空间: ${CYAN}df -h${NC}"
    echo ""
    
    # 尝试恢复配置
    if [[ -n "$NOFX_CONFIG_BACKUP" ]] && [[ -f "$NOFX_CONFIG_BACKUP" ]]; then
        log_info "尝试恢复配置文件..."
        cp "$NOFX_CONFIG_BACKUP" "$PROJECT_DIR/config.json" 2>/dev/null || true
        log_message "配置文件已恢复"
    fi
    
    echo -e "${YELLOW}如需帮助，请访问:${NC}"
    echo -e "  • GitHub Issues: ${BLUE}https://github.com/tinkle-community/nofx/issues${NC}"
    echo -e "  • Twitter: ${BLUE}@hangzai${NC}"
    echo ""
    
    exit $exit_code
}

# 设置错误处理
trap 'handle_error $LINENO' ERR

# ================================
# 主函数
# ================================
main() {
    # 记录开始时间
    START_TIME=$(date +%s)
    
    # 初始化日志
    echo "NOFX 更新日志 - $(date)" > "$UPDATE_LOG"
    echo "═══════════════════════════════════════" >> "$UPDATE_LOG"
    echo "" >> "$UPDATE_LOG"
    
    # 检查 root 权限
    check_root
    
    # 显示横幅
    print_banner
    
    # 用户确认
    echo -e "${YELLOW}⚠️  此脚本将强制更新 NOFX 到最新版本${NC}"
    echo -e "${YELLOW}   操作包括：停止服务、更新代码、重建镜像、启动服务${NC}"
    echo ""
    read -p "确认继续？(y/n): " confirm
    
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo -e "${CYAN}更新已取消${NC}"
        exit 0
    fi
    
    echo ""
    
    # 执行更新流程
    check_environment
    backup_config
    stop_services
    update_code
    restore_config
    rebuild_docker
    start_services
    health_check
    
    # 显示摘要
    show_summary
    
    # 记录成功
    echo "" >> "$UPDATE_LOG"
    echo "═══════════════════════════════════════" >> "$UPDATE_LOG"
    echo "更新成功完成于: $(date)" >> "$UPDATE_LOG"
    echo "═══════════════════════════════════════" >> "$UPDATE_LOG"
}

# ================================
# 脚本入口
# ================================

# 捕获 Ctrl+C
trap 'echo -e "\n${RED}${BOLD}更新已被用户取消${NC}"; exit 130' INT

# 运行主函数
main "$@"
