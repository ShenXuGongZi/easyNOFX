#!/bin/bash

# ================================================================
# NOFX AI 交易机器人 - Ubuntu 24.04 LTS 专用一键部署脚本
# ================================================================
# 作者: 375.btc (行雲) | Twitter: @hangzai
# 演示网站: https://hype.teidihen.com/
# 项目地址: https://github.com/tinkle-community/nofx
# 系统要求: Ubuntu 24.04 LTS (Noble Numbat)
# ================================================================

set -e  # 遇到错误立即退出

# ================================
# 颜色和样式定义
# ================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ================================
# 全局变量
# ================================
EXCHANGE=""
EXCHANGE_NAME=""
API_KEY=""
API_SECRET=""
DEEPSEEK_KEY=""
TRADER_NAME=""
INITIAL_BALANCE="1000"
PRIVATE_KEY=""
WALLET_ADDRESS=""
ASTER_USER=""
ASTER_SIGNER=""
ASTER_PRIVATE_KEY=""
PROJECT_DIR="/opt/nofx"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/nofx_install.log"
NOFX_USER="nofx"

# ================================
# 系统检查
# ================================
check_system() {
    # 检查是否为 root 用户
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要使用 root 用户运行！"
        print_info "请使用以下命令切换到 root 用户："
        print_info "  sudo su -"
        print_info "或者使用 sudo 运行此脚本："
        print_info "  sudo bash $0"
        exit 1
    fi

    print_message "已使用 root 用户运行 ✓"

    # 检查是否为 Ubuntu
    if [[ ! -f /etc/os-release ]]; then
        print_error "无法检测操作系统信息"
        exit 1
    fi

    source /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]]; then
        print_error "此脚本仅支持 Ubuntu 系统！"
        print_error "检测到的系统: $ID"
        exit 1
    fi

    # 检查 Ubuntu 版本
    if [[ "$VERSION_ID" != "24.04" ]]; then
        print_warning "检测到 Ubuntu $VERSION_ID"
        print_warning "此脚本专为 Ubuntu 24.04 LTS 优化"
        read -p "是否继续安装？(y/n): " continue_install
        if [[ $continue_install != "y" && $continue_install != "Y" ]]; then
            print_info "安装已取消"
            exit 0
        fi
    fi

    # 检查磁盘空间（至少需要 5GB）
    local available_space=$(df -BG /opt 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_space -lt 5 ]]; then
        print_warning "磁盘可用空间不足 5GB (当前: ${available_space}GB)"
        read -p "是否继续？(y/n): " continue_install
        if [[ $continue_install != "y" && $continue_install != "Y" ]]; then
            exit 0
        fi
    fi

    # 检查内存（建议至少 2GB）
    local total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $total_mem -lt 2 ]]; then
        print_warning "系统内存少于 2GB，可能影响性能"
    fi

    # 创建日志目录
    mkdir -p /var/log
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
}

# ================================
# 打印函数
# ================================
print_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║     🚀 NOFX AI 交易竞赛系统 - Ubuntu 24.04 专用部署脚本         ║
║                                                                  ║
║        支持交易所: Binance | Hyperliquid | Aster                ║
║                                                                  ║
║        作者: 375.btc (行雲)  |  Twitter: @hangzai               ║
║        演示: https://hype.teidihen.com/                         ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_message() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}

print_info() {
    echo -e "${CYAN}[ℹ]${NC} $1" | tee -a "$LOG_FILE"
}

print_step() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo -e "${PURPLE}${BOLD}▶ 步骤 $1${NC}" | tee -a "$LOG_FILE"
    echo -e "${PURPLE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# ================================
# 显示欢迎信息
# ================================
show_welcome() {
    print_header
    
    # 显示系统信息
    source /etc/os-release
    echo -e "${CYAN}${BOLD}🖥️  系统信息${NC}"
    echo -e "  操作系统: ${GREEN}$PRETTY_NAME${NC}"
    echo -e "  内核版本: ${GREEN}$(uname -r)${NC}"
    echo -e "  架构: ${GREEN}$(uname -m)${NC}"
    echo -e "  当前用户: ${GREEN}root${NC}"
    echo ""
    
    echo -e "${CYAN}欢迎使用 NOFX AI 交易机器人 Ubuntu 专用部署脚本！${NC}"
    echo ""
    echo -e "${YELLOW}这个脚本将自动帮你完成：${NC}"
    echo -e "  ${GREEN}✓${NC} 创建专用系统用户 (nofx)"
    echo -e "  ${GREEN}✓${NC} 更新系统软件包"
    echo -e "  ${GREEN}✓${NC} 安装 Docker 和 Docker Compose"
    echo -e "  ${GREEN}✓${NC} 下载 NOFX 项目代码"
    echo -e "  ${GREEN}✓${NC} 配置交易所 API"
    echo -e "  ${GREEN}✓${NC} 启动交易系统"
    echo -e "  ${GREEN}✓${NC} 配置防火墙规则"
    echo ""
    echo -e "${CYAN}整个过程大约需要 ${YELLOW}5-10 分钟${CYAN}，无需任何技术背景！${NC}"
    echo ""
    echo -e "${YELLOW}💡 演示网站: ${BLUE}https://hype.teidihen.com/${NC}"
    echo -e "${YELLOW}📖 项目地址: ${BLUE}https://github.com/tinkle-community/nofx${NC}"
    echo -e "${YELLOW}👤 作者: ${BLUE}375.btc (行雲) | @hangzai${NC}"
    echo ""
    
    read -p "按回车键开始部署..."
}

# ================================
# 创建专用用户
# ================================
create_nofx_user() {
    print_step "1/10: 创建专用系统用户"
    
    # 检查用户是否已存在
    if id "$NOFX_USER" &>/dev/null; then
        print_warning "用户 $NOFX_USER 已存在"
        read -p "是否继续使用该用户？(y/n): " use_existing
        if [[ $use_existing != "y" && $use_existing != "Y" ]]; then
            print_info "安装已取消"
            exit 0
        fi
        print_message "使用现有用户: $NOFX_USER ✓"
    else
        print_info "创建系统用户: $NOFX_USER"
        
        # 创建系统用户（无登录 shell，更安全）
        useradd -r -m -d /home/$NOFX_USER -s /bin/bash $NOFX_USER
        
        print_message "用户创建成功: $NOFX_USER ✓"
    fi
    
    # 创建项目目录
    mkdir -p "$PROJECT_DIR"
    chown -R $NOFX_USER:$NOFX_USER "$PROJECT_DIR"
    print_message "项目目录创建成功: $PROJECT_DIR ✓"
}

# ================================
# 更新系统软件包
# ================================
update_system() {
    print_step "2/10: 更新系统软件包"
    
    print_info "正在更新软件包列表..."
    
    # 备份当前的 sources.list
    cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d) 2>/dev/null || true
    
    # 更新软件包列表
    if apt-get update >> "$LOG_FILE" 2>&1; then
        print_message "软件包列表更新成功 ✓"
    else
        print_warning "软件包列表更新失败，尝试修复..."
        
        # 尝试修复损坏的包
        apt-get --fix-broken install -y >> "$LOG_FILE" 2>&1 || true
        dpkg --configure -a >> "$LOG_FILE" 2>&1 || true
        
        # 再次尝试更新
        if apt-get update >> "$LOG_FILE" 2>&1; then
            print_message "修复后更新成功 ✓"
        else
            print_error "无法更新软件包列表"
            print_info "请检查网络连接和 APT 源配置"
            exit 1
        fi
    fi
    
    # 询问是否升级系统（可选）
    print_info "检查系统更新..."
    local updates=$(apt list --upgradable 2>/dev/null | grep -v "Listing" | wc -l)
    
    if [[ $updates -gt 0 ]]; then
        print_warning "发现 $updates 个可更新的软件包"
        read -p "是否现在升级系统？(建议选 n，稍后手动升级) (y/n): " upgrade_system
        
        if [[ $upgrade_system == "y" || $upgrade_system == "Y" ]]; then
            print_info "正在升级系统，可能需要几分钟..."
            DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >> "$LOG_FILE" 2>&1
            print_message "系统升级完成 ✓"
        else
            print_info "跳过系统升级"
        fi
    else
        print_message "系统已是最新版本 ✓"
    fi
}

# ================================
# 安装基础工具
# ================================
install_basic_tools() {
    print_step "3/10: 安装基础工具"
    
    local tools=(
        "curl"
        "wget"
        "git"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "software-properties-common"
        "apt-transport-https"
    )
    
    print_info "安装必要的基础工具..."
    
    for tool in "${tools[@]}"; do
        if dpkg -l | grep -q "^ii.*$tool"; then
            print_message "$tool 已安装 ✓"
        else
            print_info "正在安装 $tool..."
            if DEBIAN_FRONTEND=noninteractive apt-get install -y "$tool" >> "$LOG_FILE" 2>&1; then
                print_message "$tool 安装成功 ✓"
            else
                print_error "$tool 安装失败"
                exit 1
            fi
        fi
    done
    
    print_message "基础工具安装完成 ✓"
}

# ================================
# 安装 Docker
# ================================
install_docker() {
    print_step "4/10: 安装 Docker 环境"
    
    # 检查 Docker 是否已安装
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        print_message "Docker 已安装 (版本: $DOCKER_VERSION) ✓"
        
        # 检查 Docker 服务状态
        if systemctl is-active --quiet docker; then
            print_message "Docker 服务运行中 ✓"
        else
            print_warning "Docker 服务未运行，正在启动..."
            systemctl start docker
            systemctl enable docker
            print_message "Docker 服务已启动 ✓"
        fi
    else
        print_info "Docker 未安装，开始安装官方版本..."
        
        # 卸载旧版本（如果存在）
        print_info "清理旧版本 Docker..."
        apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # 添加 Docker 官方 GPG 密钥
        print_info "添加 Docker 官方 GPG 密钥..."
        install -m 0755 -d /etc/apt/keyrings
        
        if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>> "$LOG_FILE"; then
            chmod a+r /etc/apt/keyrings/docker.gpg
            print_message "GPG 密钥添加成功 ✓"
        else
            print_error "GPG 密钥添加失败"
            exit 1
        fi
        
        # 添加 Docker 仓库
        print_info "添加 Docker 官方仓库..."
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # 更新软件包索引
        print_info "更新软件包索引..."
        apt-get update >> "$LOG_FILE" 2>&1
        
        # 安装 Docker Engine
        print_info "安装 Docker Engine（可能需要几分钟）..."
        if DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "$LOG_FILE" 2>&1; then
            print_message "Docker 安装成功 ✓"
            
            # 启动 Docker 服务
            systemctl start docker
            systemctl enable docker
            print_message "Docker 服务已启动并设置为开机自启 ✓"
        else
            print_error "Docker 安装失败"
            print_info "详细日志: $LOG_FILE"
            exit 1
        fi
    fi
    
    # 将 nofx 用户添加到 docker 组
    if groups $NOFX_USER 2>/dev/null | grep -q docker; then
        print_message "用户 $NOFX_USER 已在 docker 组中 ✓"
    else
        print_info "将用户 $NOFX_USER 添加到 docker 组..."
        usermod -aG docker $NOFX_USER
        print_message "用户已添加到 docker 组 ✓"
    fi
    
    # 验证 Docker Compose
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "v2+")
        print_message "Docker Compose 已安装 (版本: $COMPOSE_VERSION) ✓"
    else
        print_error "Docker Compose 未找到"
        exit 1
    fi
    
    # 测试 Docker 运行
    print_info "测试 Docker 运行..."
    if docker run --rm hello-world >> "$LOG_FILE" 2>&1; then
        print_message "Docker 运行测试成功 ✓"
    else
        print_error "Docker 运行测试失败"
        exit 1
    fi
}

# ================================
# 下载项目代码
# ================================
clone_project() {
    print_step "5/10: 下载项目代码"
    
    # 如果目录已存在，询问是否删除
    if [[ -d "$PROJECT_DIR/.git" ]]; then
        print_warning "检测到项目目录已存在: $PROJECT_DIR"
        
        # 检查是否有正在运行的容器
        cd "$PROJECT_DIR"
        if docker compose ps 2>/dev/null | grep -q "Up"; then
            print_warning "检测到正在运行的 NOFX 服务"
            read -p "是否停止服务并重新部署？(y/n): " stop_service
            if [[ $stop_service == "y" || $stop_service == "Y" ]]; then
                docker compose down
                print_message "服务已停止"
            else
                print_info "保留现有部署"
                return
            fi
        fi
        
        read -p "是否删除旧目录并重新下载？(y/n): " delete_old
        if [[ $delete_old == "y" || $delete_old == "Y" ]]; then
            # 备份配置文件
            if [[ -f "$PROJECT_DIR/config.json" ]]; then
                cp "$PROJECT_DIR/config.json" "/tmp/nofx_config_backup.json"
                print_info "已备份配置文件到: /tmp/nofx_config_backup.json"
            fi
            
            cd /opt
            rm -rf "$PROJECT_DIR"
            print_message "已删除旧目录"
        else
            print_info "将使用现有目录"
            cd "$PROJECT_DIR"
            
            # 尝试更新代码
            print_info "尝试更新代码..."
            if sudo -u $NOFX_USER git pull origin main >> "$LOG_FILE" 2>&1; then
                print_message "代码更新成功 ✓"
            else
                print_warning "代码更新失败，将使用现有版本"
            fi
            return
        fi
    fi
    
    print_info "正在从 GitHub 克隆项目..."
    print_info "仓库: https://github.com/tinkle-community/nofx.git"
    
    # 克隆项目（以 nofx 用户身份）
    cd /opt
    if sudo -u $NOFX_USER git clone --progress https://github.com/tinkle-community/nofx.git "$PROJECT_DIR" 2>&1 | tee -a "$LOG_FILE"; then
        print_message "项目下载成功 ✓"
        cd "$PROJECT_DIR"
        
        # 设置正确的权限
        chown -R $NOFX_USER:$NOFX_USER "$PROJECT_DIR"
        
        # 显示项目信息
        local commit_hash=$(sudo -u $NOFX_USER git rev-parse --short HEAD)
        local commit_date=$(sudo -u $NOFX_USER git log -1 --format=%cd --date=short)
        print_info "项目版本: $commit_hash ($commit_date)"
        
        # 恢复备份的配置（如果存在）
        if [[ -f "/tmp/nofx_config_backup.json" ]]; then
            print_info "检测到备份配置文件"
            read -p "是否恢复备份的配置？(y/n): " restore_config
            if [[ $restore_config == "y" || $restore_config == "Y" ]]; then
                cp "/tmp/nofx_config_backup.json" "config.json"
                chown $NOFX_USER:$NOFX_USER "config.json"
                print_message "配置文件已恢复 ✓"
            fi
        fi
    else
        print_error "项目下载失败"
        print_error "可能的原因："
        print_error "  1. 网络连接问题"
        print_error "  2. GitHub 访问受限（可能需要代理）"
        print_error "  3. Git 未正确安装"
        exit 1
    fi
}

# ================================
# 选择交易所
# ================================
select_exchange() {
    print_step "6/10: 选择交易所"
    
    echo -e "${CYAN}${BOLD}支持的交易所：${NC}"
    echo ""
    echo -e "  ${GREEN}1) Aster${NC}       - ${YELLOW}⚡ 推荐新手${NC} 去中心化永续合约（1001倍杠杆）"
    echo -e "     ${BLUE}• Binance 兼容 API，迁移简单${NC}"
    echo -e "     ${BLUE}• API 钱包系统，资金隔离安全${NC}"
    echo -e "     ${BLUE}• 低手续费，支持多链 (ETH/BSC/Polygon)${NC}"
    echo -e "     ${BLUE}• 注册地址: https://www.asterdex.com/zh-CN/referral/961369${NC}"
    echo ""
    echo -e "  ${GREEN}2) Binance${NC}     - ${YELLOW}🏆 全球最大${NC} 中心化交易所"
    echo -e "     ${BLUE}• 流动性最好，交易对最多${NC}"
    echo -e "     ${BLUE}• API 稳定，文档完善${NC}"
    echo -e "     ${BLUE}• 需要 KYC 认证${NC}"
    echo -e "     ${BLUE}• 注册地址: https://accounts.binance.com/register?ref=1046713645${NC}"
    echo ""
    echo -e "  ${GREEN}3) Hyperliquid${NC} - ${YELLOW}🔒 最安全${NC} 去中心化永续合约"
    echo -e "     ${BLUE}• 链上结算，非托管（你控制资金）${NC}"
    echo -e "     ${BLUE}• 低手续费，无 KYC${NC}"
    echo -e "     ${BLUE}• 只需以太坊钱包私钥${NC}"
    echo -e "     ${BLUE}• 注册地址: https://app.hyperliquid.xyz/join/HANGZAI${NC}"
    echo ""
    
    while true; do
        read -p "请选择交易所 (1-3，推荐新手选 1): " exchange_choice
        case $exchange_choice in
            1)
                EXCHANGE="aster"
                EXCHANGE_NAME="Aster"
                REGISTER_URL="https://www.asterdex.com/zh-CN/referral/961369"
                break
                ;;
            2)
                EXCHANGE="binance"
                EXCHANGE_NAME="Binance"
                REGISTER_URL="https://accounts.binance.com/register?ref=1046713645"
                break
                ;;
            3)
                EXCHANGE="hyperliquid"
                EXCHANGE_NAME="Hyperliquid"
                REGISTER_URL="https://app.hyperliquid.xyz/join/HANGZAI"
                break
                ;;
            *)
                print_error "无效选项，请输入 1、2 或 3"
                ;;
        esac
    done
    
    echo ""
    print_message "已选择: ${EXCHANGE_NAME}"
    echo -e "${CYAN}专属邀请链接: ${BLUE}$REGISTER_URL${NC}"
}

# ================================
# 账号注册引导
# ================================
guide_registration() {
    print_step "7/10: 账号注册引导"
    
    echo -e "${CYAN}${BOLD}您是否已拥有 ${EXCHANGE_NAME} 账号？${NC}"
    echo ""
    read -p "已有账号请输入 y，没有请输入 n (y/n): " has_account
    
    if [[ $has_account != "y" && $has_account != "Y" ]]; then
        echo ""
        print_warning "您需要先注册 ${EXCHANGE_NAME} 账号"
        echo ""
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ${YELLOW}🎁 专属邀请链接（享受手续费返佣优惠）${GREEN}                   ║${NC}"
        echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║                                                               ║${NC}"
        echo -e "${GREEN}║  ${BLUE}$REGISTER_URL${NC}"
        echo -e "${GREEN}║                                                               ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # 根据交易所显示不同的注册步骤
        if [[ "$EXCHANGE" == "aster" ]]; then
            echo -e "${CYAN}${BOLD}📝 Aster 快速注册指南：${NC}"
            echo ""
            echo -e "${YELLOW}第一步: 注册账号${NC}"
            echo "  1️⃣  访问上方邀请链接"
            echo "  2️⃣  连接你的钱包 (推荐 MetaMask)"
            echo "  3️⃣  完成账号激活"
            echo ""
            echo -e "${YELLOW}第二步: 创建 API 钱包（重要！）${NC}"
            echo "  4️⃣  访问: https://www.asterdex.com/zh-CN/futures/api-wallet"
            echo "  5️⃣  点击「创建 API 钱包」按钮"
            echo "  6️⃣  ${RED}${BOLD}立即保存${NC}以下信息（${RED}只显示一次！${NC}）："
            echo ""
            echo -e "${CYAN}      ┌─────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}      │ ${YELLOW}• 主钱包地址 (User)${CYAN}                    │${NC}"
            echo -e "${CYAN}      │ ${YELLOW}• API 钱包地址 (Signer)${CYAN}                │${NC}"
            echo -e "${CYAN}      │ ${YELLOW}• API 钱包私钥 (Private Key)${CYAN}           │${NC}"
            echo -e "${CYAN}      └─────────────────────────────────────────────┘${NC}"
            echo ""
            echo -e "${YELLOW}第三步: 充值资金${NC}"
            echo "  7️⃣  向主钱包充值 USDT（用于交易）"
            echo "  8️⃣  建议先充值少量测试（如 100-500 USDT）"
            echo ""
            echo -e "${RED}${BOLD}⚠️ 安全提示：${NC}"
            echo -e "  ${RED}•${NC} API 钱包私钥只显示一次，务必妥善保存"
            echo -e "  ${RED}•${NC} 建议使用密码管理器保存"
            echo -e "  ${RED}•${NC} 不要与他人分享私钥"
            echo ""
            
        elif [[ "$EXCHANGE" == "binance" ]]; then
            echo -e "${CYAN}${BOLD}📝 Binance 快速注册指南：${NC}"
            echo ""
            echo -e "${YELLOW}第一步: 注册账号${NC}"
            echo "  1️⃣  访问上方邀请链接"
            echo "  2️⃣  使用邮箱或手机号注册"
            echo "  3️⃣  完成身份验证 (KYC)"
            echo "  4️⃣  开启双重验证 (Google Authenticator 推荐)"
            echo ""
            echo -e "${YELLOW}第二步: 开通合约账户${NC}"
            echo "  5️⃣  登录币安 → 衍生品 → U本位合约"
            echo "  6️⃣  点击「开通」开启合约交易"
            echo "  7️⃣  阅读并同意合约交易协议"
            echo ""
            echo -e "${YELLOW}第三步: 创建 API 密钥${NC}"
            echo "  8️⃣  前往: 个人中心 → API 管理"
            echo "  9️⃣  点击「创建 API」"
            echo "  🔟  ${BOLD}权限设置（重要）：${NC}"
            echo ""
            echo -e "${CYAN}      ┌─────────────────────────────────────────────┐${NC}"
            echo -e "${CYAN}      │ ${GREEN}✓${NC} 启用「读取」                          ${CYAN}│${NC}"
            echo -e "${CYAN}      │ ${GREEN}✓${NC} 启用「现货与杠杆交易」               ${CYAN}│${NC}"
            echo -e "${CYAN}      │ ${GREEN}✓${NC} 启用「期货」                         ${CYAN}│${NC}"
            echo -e "${CYAN}      │ ${RED}✗${NC} 不要启用「提现」（安全考虑）         ${CYAN}│${NC}"
            echo -e "${CYAN}      └─────────────────────────────────────────────┘${NC}"
            echo ""
            echo "  1️⃣1️⃣  ${BOLD}建议设置 IP 白名单${NC}（更安全）"
            echo "  1️⃣2️⃣  保存 API Key 和 Secret Key"
            echo ""
            echo -e "${YELLOW}第四步: 充值资金${NC}"
            echo "  1️⃣3️⃣  划转资金到合约账户"
            echo "  1️⃣4️⃣  建议先充值少量测试（如 100-500 USDT）"
            echo ""
            echo -e "${RED}${BOLD}⚠️ 安全提示：${NC}"
            echo -e "  ${RED}•${NC} 务必开启双重验证 (2FA)"
            echo -e "  ${RED}•${NC} API Key 不要启用提现权限"
            echo -e "  ${RED}•${NC} 建议设置 IP 白名单"
            echo ""
            
        else  # hyperliquid
            echo -e "${CYAN}${BOLD}📝 Hyperliquid 快速注册指南：${NC}"
            echo ""
            echo -e "${YELLOW}第一步: 连接钱包${NC}"
            echo "  1️⃣  访问上方邀请链接"
            echo "  2️⃣  点击「Connect Wallet」"
            echo "  3️⃣  选择 MetaMask（推荐）或其他钱包"
            echo "  4️⃣  授权连接"
            echo ""
            echo -e "${YELLOW}第二步: 导出私钥${NC}"
            echo "  5️⃣  ${RED}${BOLD}安全建议：使用专用钱包，不要用主钱包！${NC}"
            echo "  6️⃣  打开 MetaMask → 账户详情"
            echo "  7️⃣  点击「导出私钥」"
            echo "  8️⃣  输入密码确认"
            echo "  9️⃣  ${BOLD}复制私钥并移除前面的 0x${NC}"
            echo ""
            echo -e "${YELLOW}第三步: 充值资金${NC}"
            echo "  🔟  向钱包地址充值 USDC (Arbitrum 链)"
            echo "  1️⃣1️⃣  或使用 Hyperliquid 内置的跨链桥"
            echo "  1️⃣2️⃣  建议先充值少量测试（如 100-500 USDT）"
            echo ""
            echo -e "${RED}${BOLD}⚠️ 安全提示：${NC}"
            echo -e "  ${RED}•${NC} ${BOLD}强烈建议创建新钱包专门用于交易${NC}"
            echo -e "  ${RED}•${NC} 不要使用存有大量资金的主钱包"
            echo -e "  ${RED}•${NC} 私钥泄露将导致资金损失"
            echo -e "  ${RED}•${NC} 妥善保管私钥，不要与任何人分享"
            echo ""
        fi
        
        print_info "完成上述步骤后，按回车键继续..."
        read
        
    else
        print_message "已有账号，继续配置 ✓"
    fi
}

# ================================
# 获取 API 凭证
# ================================
get_api_credentials() {
    print_step "8/10: 配置 API 凭证"
    
    echo -e "${CYAN}${BOLD}请输入您的交易配置信息${NC}"
    echo ""
    
    # 交易者名称
    read -p "交易者名称 (默认: My_AI_Trader，可直接回车): " trader_input
    TRADER_NAME=${trader_input:-"My_AI_Trader"}
    echo ""
    
    # 根据交易所类型获取不同的凭证
    if [[ "$EXCHANGE" == "aster" ]]; then
        echo -e "${YELLOW}${BOLD}━━━ Aster API 钱包信息 ━━━${NC}"
        echo ""
        
        while [[ -z "$ASTER_USER" ]]; do
            read -p "主钱包地址 (User, 以 0x 开头): " ASTER_USER
            if [[ -z "$ASTER_USER" ]]; then
                print_error "主钱包地址不能为空"
            elif [[ ! "$ASTER_USER" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
                print_warning "地址格式可能不正确，请确认"
                read -p "确认使用此地址？(y/n): " confirm
                if [[ $confirm == "y" || $confirm == "Y" ]]; then
                    break
                else
                    ASTER_USER=""
                fi
            fi
        done
        
        while [[ -z "$ASTER_SIGNER" ]]; do
            read -p "API 钱包地址 (Signer, 以 0x 开头): " ASTER_SIGNER
            if [[ -z "$ASTER_SIGNER" ]]; then
                print_error "API 钱包地址不能为空"
            elif [[ ! "$ASTER_SIGNER" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
                print_warning "地址格式可能不正确，请确认"
                read -p "确认使用此地址？(y/n): " confirm
                if [[ $confirm == "y" || $confirm == "Y" ]]; then
                    break
                else
                    ASTER_SIGNER=""
                fi
            fi
        done
        
        while [[ -z "$ASTER_PRIVATE_KEY" ]]; do
            read -sp "API 钱包私钥 (64位16进制，无需 0x 前缀): " ASTER_PRIVATE_KEY
            echo ""
            if [[ -z "$ASTER_PRIVATE_KEY" ]]; then
                print_error "API 钱包私钥不能为空"
            else
                # 移除可能存在的 0x 前缀
                ASTER_PRIVATE_KEY=${ASTER_PRIVATE_KEY#0x}
                
                # 验证长度
                if [[ ${#ASTER_PRIVATE_KEY} != 64 ]]; then
                    print_warning "私钥长度异常（应为64个字符），当前: ${#ASTER_PRIVATE_KEY}"
                    read -p "确认使用此私钥？(y/n): " confirm
                    if [[ $confirm != "y" && $confirm != "Y" ]]; then
                        ASTER_PRIVATE_KEY=""
                    fi
                fi
            fi
        done
        
    elif [[ "$EXCHANGE" == "binance" ]]; then
        echo -e "${YELLOW}${BOLD}━━━ Binance API 信息 ━━━${NC}"
        echo ""
        
        while [[ -z "$API_KEY" ]]; do
            read -p "API Key (从币安 API 管理获取): " API_KEY
            if [[ -z "$API_KEY" ]]; then
                print_error "API Key 不能为空"
            fi
        done
        
        while [[ -z "$API_SECRET" ]]; do
            read -sp "API Secret (从币安 API 管理获取): " API_SECRET
            echo ""
            if [[ -z "$API_SECRET" ]]; then
                print_error "API Secret 不能为空"
            fi
        done
        
    else  # hyperliquid
        echo -e "${YELLOW}${BOLD}━━━ Hyperliquid 钱包信息 ━━━${NC}"
        echo ""
        
        while [[ -z "$WALLET_ADDRESS" ]]; do
            read -p "钱包地址 (0x...): " WALLET_ADDRESS
            if [[ -z "$WALLET_ADDRESS" ]]; then
                print_error "钱包地址不能为空"
            elif [[ ! "$WALLET_ADDRESS" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
                print_warning "地址格式可能不正确，请确认"
                read -p "确认使用此地址？(y/n): " confirm
                if [[ $confirm == "y" || $confirm == "Y" ]]; then
                    break
                else
                    WALLET_ADDRESS=""
                fi
            fi
        done
        
        while [[ -z "$PRIVATE_KEY" ]]; do
            read -sp "私钥 (64位16进制，无需 0x 前缀): " PRIVATE_KEY
            echo ""
            if [[ -z "$PRIVATE_KEY" ]]; then
                print_error "私钥不能为空"
            else
                # 移除可能存在的 0x 前缀
                PRIVATE_KEY=${PRIVATE_KEY#0x}
                
                # 验证长度
                if [[ ${#PRIVATE_KEY} != 64 ]]; then
                    print_warning "私钥长度异常（应为64个字符），当前: ${#PRIVATE_KEY}"
                    read -p "确认使用此私钥？(y/n): " confirm
                    if [[ $confirm != "y" && $confirm != "Y" ]]; then
                        PRIVATE_KEY=""
                    fi
                fi
            fi
        done
    fi
    
    # DeepSeek API Key（所有交易所都需要）
    echo ""
    echo -e "${YELLOW}${BOLD}━━━ DeepSeek AI 配置 ━━━${NC}"
    print_info "DeepSeek 是 AI 决策引擎，负责分析市场并做出交易决策"
    print_info "注册地址: ${BLUE}https://platform.deepseek.com/${NC}"
    print_info "充值建议: 最少 $5 USD，推荐 $20-50 USD 用于测试"
    echo ""
    
    while [[ -z "$DEEPSEEK_KEY" ]]; do
        read -p "DeepSeek API Key (以 sk- 开头): " DEEPSEEK_KEY
        if [[ -z "$DEEPSEEK_KEY" ]]; then
            print_error "DeepSeek API Key 不能为空"
        elif [[ ! "$DEEPSEEK_KEY" =~ ^sk- ]]; then
            print_warning "API Key 格式可能不正确（应以 sk- 开头）"
            read -p "确认使用此密钥？(y/n): " confirm
            if [[ $confirm != "y" && $confirm != "Y" ]]; then
                DEEPSEEK_KEY=""
            fi
        fi
    done
    
    # 初始资金
    echo ""
    echo -e "${YELLOW}${BOLD}━━━ 初始资金设置 ━━━${NC}"
    print_info "此设置用于计算盈亏百分比，建议设置为实际账户余额"
    read -p "初始模拟资金 USDT (默认: 1000，可直接回车): " balance_input
    INITIAL_BALANCE=${balance_input:-"1000"}
    
    echo ""
    print_message "API 凭证配置完成 ✓"
    
    # 显示配置摘要（不显示敏感信息）
    echo ""
    echo -e "${CYAN}${BOLD}━━━ 配置摘要 ━━━${NC}"
    echo -e "  交易所: ${GREEN}$EXCHANGE_NAME${NC}"
    echo -e "  交易者: ${GREEN}$TRADER_NAME${NC}"
    echo -e "  初始资金: ${GREEN}$INITIAL_BALANCE USDT${NC}"
    
    if [[ "$EXCHANGE" == "aster" ]]; then
        echo -e "  主钱包: ${GREEN}$ASTER_USER${NC}"
        echo -e "  API 钱包: ${GREEN}$ASTER_SIGNER${NC}"
    elif [[ "$EXCHANGE" == "binance" ]]; then
        echo -e "  API Key: ${GREEN}${API_KEY:0:10}...${NC}"
    else
        echo -e "  钱包地址: ${GREEN}$WALLET_ADDRESS${NC}"
    fi
    echo -e "  AI 引擎: ${GREEN}DeepSeek${NC}"
    echo ""
}

# ================================
# 创建配置文件
# ================================
create_config() {
    print_step "9/10: 生成配置文件"
    
    cd "$PROJECT_DIR"
    
    print_info "正在创建 config.json..."
    
    # 根据不同交易所生成不同的配置
    if [[ "$EXCHANGE" == "aster" ]]; then
        cat > config.json <<EOF
{
  "traders": [
    {
      "id": "aster_trader_$(date +%s)",
      "name": "${TRADER_NAME}",
      "enabled": true,
      "ai_model": "deepseek",
      "exchange": "aster",
      "aster_user": "${ASTER_USER}",
      "aster_signer": "${ASTER_SIGNER}",
      "aster_private_key": "${ASTER_PRIVATE_KEY}",
      "deepseek_key": "${DEEPSEEK_KEY}",
      "initial_balance": ${INITIAL_BALANCE},
      "scan_interval_minutes": 3
    }
  ],
  "use_default_coins": true,
  "api_server_port": 8080,
  "leverage": {
    "btc_eth_leverage": 5,
    "altcoin_leverage": 5
  }
}
EOF
    elif [[ "$EXCHANGE" == "binance" ]]; then
        cat > config.json <<EOF
{
  "traders": [
    {
      "id": "binance_trader_$(date +%s)",
      "name": "${TRADER_NAME}",
      "enabled": true,
      "ai_model": "deepseek",
      "exchange": "binance",
      "binance_api_key": "${API_KEY}",
      "binance_secret_key": "${API_SECRET}",
      "deepseek_key": "${DEEPSEEK_KEY}",
      "initial_balance": ${INITIAL_BALANCE},
      "scan_interval_minutes": 3
    }
  ],
  "use_default_coins": true,
  "api_server_port": 8080,
  "leverage": {
    "btc_eth_leverage": 5,
    "altcoin_leverage": 5
  }
}
EOF
    else  # hyperliquid
        cat > config.json <<EOF
{
  "traders": [
    {
      "id": "hyperliquid_trader_$(date +%s)",
      "name": "${TRADER_NAME}",
      "enabled": true,
      "ai_model": "deepseek",
      "exchange": "hyperliquid",
      "hyperliquid_private_key": "${PRIVATE_KEY}",
      "hyperliquid_wallet_addr": "${WALLET_ADDRESS}",
      "hyperliquid_testnet": false,
      "deepseek_key": "${DEEPSEEK_KEY}",
      "initial_balance": ${INITIAL_BALANCE},
      "scan_interval_minutes": 3
    }
  ],
  "use_default_coins": true,
  "api_server_port": 8080,
  "leverage": {
    "btc_eth_leverage": 5,
    "altcoin_leverage": 5
  }
}
EOF
    fi
    
    # 设置文件权限（保护敏感信息）
    chown $NOFX_USER:$NOFX_USER config.json
    chmod 600 config.json
    print_message "配置文件创建成功: config.json (权限: 600)"
    
    # 创建必要的目录
    mkdir -p decision_logs coin_pool_cache
    chown -R $NOFX_USER:$NOFX_USER decision_logs coin_pool_cache
    print_message "数据目录创建成功"
    
    # 添加到 .gitignore（如果还没有）
    if [[ ! -f ".gitignore" ]] || ! grep -q "config.json" .gitignore; then
        echo "config.json" >> .gitignore
        chown $NOFX_USER:$NOFX_USER .gitignore
        print_message "已将 config.json 添加到 .gitignore"
    fi
    
    # 创建备份
    cp config.json config.json.backup
    chown $NOFX_USER:$NOFX_USER config.json.backup
    print_info "配置备份: config.json.backup"
}

# ================================
# 配置防火墙
# ================================
configure_firewall() {
    print_info "检查防火墙状态..."
    
    # 检查 UFW 是否安装
    if ! command -v ufw &> /dev/null; then
        print_info "UFW 未安装，正在安装..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y ufw >> "$LOG_FILE" 2>&1
        print_message "UFW 安装成功 ✓"
    fi
    
    # 检查 UFW 状态
    local ufw_status=$(ufw status | grep -i "Status:" | awk '{print $2}')
    
    if [[ "$ufw_status" != "active" ]]; then
        print_warning "防火墙未启用"
        read -p "是否启用防火墙并配置规则？(推荐选 y) (y/n): " enable_fw
        
        if [[ $enable_fw == "y" || $enable_fw == "Y" ]]; then
            print_info "配置防火墙规则..."
            
            # 重置防火墙规则
            ufw --force reset >> "$LOG_FILE" 2>&1
            
            # 设置默认策略
            ufw default deny incoming >> "$LOG_FILE" 2>&1
            ufw default allow outgoing >> "$LOG_FILE" 2>&1
            
            # 允许 SSH（确保不会断开连接）
            ufw allow 22/tcp >> "$LOG_FILE" 2>&1
            print_info "已开放端口: 22 (SSH)"
            
            # 允许 NOFX 端口
            ufw allow 8080/tcp >> "$LOG_FILE" 2>&1
            print_info "已开放端口: 8080 (API)"
            
            ufw allow 3000/tcp >> "$LOG_FILE" 2>&1
            print_info "已开放端口: 3000 (Web)"
            
            # 启用防火墙
            ufw --force enable >> "$LOG_FILE" 2>&1
            
            print_message "防火墙配置完成 ✓"
            print_info "防火墙规则:"
            ufw status numbered | tee -a "$LOG_FILE"
        else
            print_info "跳过防火墙配置"
        fi
    else
        print_message "防火墙已启用 ✓"
        
        read -p "是否配置 NOFX 端口（8080 和 3000）？(y/n): " config_ports
        
        if [[ $config_ports == "y" || $config_ports == "Y" ]]; then
            # 检查端口是否已开放
            if ! ufw status | grep -q "8080"; then
                ufw allow 8080/tcp >> "$LOG_FILE" 2>&1
                print_info "已开放端口: 8080 (API)"
            else
                print_message "端口 8080 已开放 ✓"
            fi
            
            if ! ufw status | grep -q "3000"; then
                ufw allow 3000/tcp >> "$LOG_FILE" 2>&1
                print_info "已开放端口: 3000 (Web)"
            else
                print_message "端口 3000 已开放 ✓"
            fi
            
            # 重新加载规则
            ufw reload >> "$LOG_FILE" 2>&1
            
            print_message "防火墙规则更新完成 ✓"
            print_info "当前规则:"
            ufw status numbered | tee -a "$LOG_FILE"
        fi
    fi
}

# ================================
# 部署 Docker 服务
# ================================
deploy_docker() {
    print_step "10/10: 启动 Docker 服务"
    
    cd "$PROJECT_DIR"
    
    print_info "正在构建并启动服务，这可能需要几分钟..."
    print_info "首次构建会下载必要的镜像，请耐心等待..."
    echo ""
    
    # 停止旧服务（如果存在）
    if docker compose ps 2>/dev/null | grep -q "Up"; then
        print_info "检测到旧服务正在运行，正在停止..."
        docker compose down >> "$LOG_FILE" 2>&1
        print_message "旧服务已停止 ✓"
    fi
    
    # 清理旧容器（如果存在）
    print_info "清理旧容器和网络..."
    docker compose down --remove-orphans >> "$LOG_FILE" 2>&1 || true
    
    # 构建并启动（显示进度）
    print_info "开始构建 Docker 镜像..."
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if docker compose up -d --build 2>&1 | tee -a "$LOG_FILE" | grep -E "Building|Pulling|Creating|Starting"; then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        print_message "Docker 服务启动成功 ✓"
    else
        echo ""
        print_error "Docker 服务启动失败"
        print_info "查看详细日志: docker compose logs"
        exit 1
    fi
    
    # 配置防火墙
    configure_firewall
    
    # 等待服务启动
    print_info "等待服务完全启动（预计 10-15 秒）..."
    
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
    print_info "容器状态:"
    docker compose ps | tee -a "$LOG_FILE"
    echo ""
    
    # 健康检查
    print_info "执行健康检查..."
    
    local retries=0
    local max_retries=15
    local backend_ok=false
    local frontend_ok=false
    
    # 检查后端
    print_info "检查后端服务..."
    while [ $retries -lt $max_retries ]; do
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            print_message "后端服务健康检查通过 ✓"
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
        print_warning "后端服务可能还在启动中"
        print_info "可以运行查看日志: docker compose logs backend"
    fi
    
    # 检查前端
    print_info "检查前端服务..."
    retries=0
    while [ $retries -lt $max_retries ]; do
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            print_message "前端服务健康检查通过 ✓"
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
        print_warning "前端服务可能还在启动中"
        print_info "可以运行查看日志: docker compose logs frontend"
    fi
    
    # 显示资源使用情况
    print_info "容器资源使用情况:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -4 | tee -a "$LOG_FILE"
}

# ================================
# 显示部署信息
# ================================
show_deployment_info() {
    clear
    echo ""
    echo -e "${GREEN}${BOLD}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║                    🎉 部署完成！                               ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # 获取服务器 IP（如果有公网IP）
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s api.ipify.org 2>/dev/null || echo "localhost")
    
    echo -e "${CYAN}${BOLD}📊 访问地址${NC}"
    echo ""
    echo -e "  ${YELLOW}本地访问:${NC}"
    echo -e "    • Web 控制台: ${BLUE}http://localhost:3000${NC}"
    echo -e "    • API 接口:   ${BLUE}http://localhost:8080${NC}"
    echo -e "    • 健康检查:   ${BLUE}http://localhost:8080/health${NC}"
    echo ""
    
    if [[ "$server_ip" != "localhost" ]]; then
        echo -e "  ${YELLOW}远程访问 (如果开放了防火墙):${NC}"
        echo -e "    • Web 控制台: ${BLUE}http://$server_ip:3000${NC}"
        echo -e "    • API 接口:   ${BLUE}http://$server_ip:8080${NC}"
        echo ""
        echo -e "  ${RED}⚠️ 安全提示:${NC} 建议配置反向代理 (Nginx) 和 HTTPS"
        echo ""
    fi
    
    echo -e "${CYAN}${BOLD}🎯 快速开始${NC}"
    echo ""
    echo -e "  1. 打开浏览器访问: ${BLUE}http://localhost:3000${NC} 或 ${BLUE}http://$server_ip:3000${NC}"
    echo -e "  2. 等待 3-5 分钟，AI 将开始分析市场"
    echo -e "  3. 查看实时决策日志和交易信息"
    echo -e "  4. 监控账户余额变化"
    echo ""
    
    echo -e "${CYAN}${BOLD}🔧 常用命令 (使用 root 用户执行)${NC}"
    echo ""
    echo -e "  ${YELLOW}进入项目目录:${NC}"
    echo -e "    cd $PROJECT_DIR"
    echo ""
    echo -e "  ${YELLOW}查看实时日志:${NC}"
    echo -e "    docker compose logs -f                 # 所有服务"
    echo -e "    docker compose logs -f backend         # 后端日志"
    echo -e "    docker compose logs -f frontend        # 前端日志"
    echo ""
    echo -e "  ${YELLOW}查看服务状态:${NC}"
    echo -e "    docker compose ps                      # 容器状态"
    echo -e "    docker stats                           # 资源使用"
    echo ""
    echo -e "  ${YELLOW}控制服务:${NC}"
    echo -e "    docker compose stop                    # 停止服务"
    echo -e "    docker compose start                   # 启动服务"
    echo -e "    docker compose restart                 # 重启服务"
    echo -e "    docker compose down                    # 删除容器"
    echo ""
    echo -e "  ${YELLOW}配置管理:${NC}"
    echo -e "    nano $PROJECT_DIR/config.json          # 编辑配置"
    echo -e "    docker compose restart                 # 重启应用配置"
    echo ""
    
    echo -e "${CYAN}${BOLD}📁 重要文件位置${NC}"
    echo ""
    echo -e "  ${YELLOW}配置文件:${NC}      $PROJECT_DIR/config.json"
    echo -e "  ${YELLOW}配置备份:${NC}      $PROJECT_DIR/config.json.backup"
    echo -e "  ${YELLOW}决策日志:${NC}      $PROJECT_DIR/decision_logs/"
    echo -e "  ${YELLOW}安装日志:${NC}      $LOG_FILE"
    echo -e "  ${YELLOW}项目目录:${NC}      $PROJECT_DIR"
    echo -e "  ${YELLOW}系统用户:${NC}      $NOFX_USER"
    echo ""
    
    echo -e "${CYAN}${BOLD}⚙️ 系统配置${NC}"
    echo ""
    echo -e "  ${YELLOW}操作系统:${NC}      Ubuntu $(lsb_release -rs)"
    echo -e "  ${YELLOW}Docker 版本:${NC}   $(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)"
    echo -e "  ${YELLOW}部署用户:${NC}      root"
    echo -e "  ${YELLOW}运行用户:${NC}      $NOFX_USER"
    echo -e "  ${YELLOW}交易所:${NC}        ${EXCHANGE_NAME}"
    echo -e "  ${YELLOW}交易者名称:${NC}    ${TRADER_NAME}"
    echo -e "  ${YELLOW}初始资金:${NC}      ${INITIAL_BALANCE} USDT"
    echo -e "  ${YELLOW}决策周期:${NC}      3 分钟"
    echo -e "  ${YELLOW}AI 引擎:${NC}       DeepSeek"
    echo ""
    
    echo -e "${CYAN}${BOLD}🌐 相关链接${NC}"
    echo ""
    echo -e "  ${YELLOW}演示网站:${NC}      ${BLUE}https://hype.teidihen.com/${NC}"
    echo -e "  ${YELLOW}项目地址:${NC}      ${BLUE}https://github.com/tinkle-community/nofx${NC}"
    echo -e "  ${YELLOW}部署文档:${NC}      ${BLUE}https://github.com/tinkle-community/nofx/blob/main/DOCKER_DEPLOY.md${NC}"
    echo -e "  ${YELLOW}问题反馈:${NC}      ${BLUE}https://github.com/tinkle-community/nofx/issues${NC}"
    echo -e "  ${YELLOW}作者 Twitter:${NC}  ${BLUE}@hangzai${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}📈 监控建议${NC}"
    echo ""
    echo -e "  ${GREEN}✓${NC} 定期查看 Web 控制台了解交易情况"
    echo -e "  ${GREEN}✓${NC} 监控账户余额变化"
    echo -e "  ${GREEN}✓${NC} 查看 AI 决策日志理解交易逻辑"
    echo -e "  ${GREEN}✓${NC} 关注市场波动，必要时手动干预"
    echo -e "  ${GREEN}✓${NC} 每天检查一次系统运行状态"
    echo -e "  ${GREEN}✓${NC} 定期备份配置文件"
    echo ""
    
    echo -e "${YELLOW}${BOLD}⚠️ 风险提示${NC}"
    echo ""
    echo -e "  ${RED}•${NC} 加密货币交易存在高风险，可能导致本金损失"
    echo -e "  ${RED}•${NC} AI 决策不能保证盈利，仅供学习研究"
    echo -e "  ${RED}•${NC} 建议先用小额资金测试（100-500 USDT）"
    echo -e "  ${RED}•${NC} 不要投入超过你能承受损失的资金"
    echo -e "  ${RED}•${NC} 定期查看系统运行状态和账户余额"
    echo -e "  ${RED}•${NC} 极端市场条件下可能发生爆仓风险"
    echo ""
    
    echo -e "${CYAN}${BOLD}🔐 安全建议${NC}"
    echo ""
    echo -e "  ${GREEN}✓${NC} 定期备份 config.json 文件"
    echo -e "  ${GREEN}✓${NC} 配置文件权限已设置为 600（仅所有者可读写）"
    echo -e "  ${GREEN}✓${NC} 不要将配置文件提交到 Git 仓库"
    echo -e "  ${GREEN}✓${NC} 使用强密码保护服务器"
    echo -e "  ${GREEN}✓${NC} 已配置防火墙保护端口"
    echo -e "  ${GREEN}✓${NC} 如需远程访问，建议配置 HTTPS"
    echo -e "  ${GREEN}✓${NC} 定期检查 API 权限设置"
    echo -e "  ${GREEN}✓${NC} 建议更改 SSH 默认端口 (22)"
    echo ""
    
    echo -e "${CYAN}${BOLD}🆘 遇到问题？${NC}"
    echo ""
    echo -e "  1. 查看日志: ${YELLOW}cd $PROJECT_DIR && docker compose logs -f${NC}"
    echo -e "  2. 检查配置: ${YELLOW}cat $PROJECT_DIR/config.json${NC}"
    echo -e "  3. 重启服务: ${YELLOW}cd $PROJECT_DIR && docker compose restart${NC}"
    echo -e "  4. 查看文档: ${BLUE}https://github.com/tinkle-community/nofx${NC}"
    echo -e "  5. 提交 Issue: ${BLUE}https://github.com/tinkle-community/nofx/issues${NC}"
    echo -e "  6. 查看安装日志: ${YELLOW}cat $LOG_FILE${NC}"
    echo ""
    
    # 创建管理脚本
    create_management_script
    
    echo -e "${CYAN}${BOLD}💡 提示：已创建管理脚本${NC}"
    echo -e "  运行 ${YELLOW}/usr/local/bin/nofx${NC} 快速管理 NOFX 服务"
    echo ""
    
    # 询问是否查看日志
    read -p "是否查看实时日志？(y/n): " view_logs
    if [[ $view_logs == "y" || $view_logs == "Y" ]]; then
        echo ""
        print_info "正在打开实时日志，按 Ctrl+C 退出查看"
        print_info "提示: 初次启动可能看到一些警告，这是正常的"
        sleep 3
        cd "$PROJECT_DIR"
        docker compose logs -f
    else
        echo ""
        echo -e "${GREEN}${BOLD}✨ 感谢使用 NOFX AI 交易竞赛系统！${NC}"
        echo -e "${CYAN}作者: 375.btc (行雲) | Twitter: @hangzai${NC}"
        echo -e "${CYAN}祝您交易顺利！🚀${NC}"
        echo ""
    fi
}

# ================================
# 创建管理脚本
# ================================
create_management_script() {
    print_info "创建管理脚本..."
    
    cat > /usr/local/bin/nofx <<'MGMT_EOF'
#!/bin/bash

# NOFX 管理脚本

PROJECT_DIR="/opt/nofx"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用 root 用户运行此脚本${NC}"
    echo "使用: sudo nofx"
    exit 1
fi

cd "$PROJECT_DIR" || exit 1

show_menu() {
    clear
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  NOFX AI 交易系统 - 管理工具       ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}1)${NC} 查看服务状态"
    echo -e "${YELLOW}2)${NC} 启动服务"
    echo -e "${YELLOW}3)${NC} 停止服务"
    echo -e "${YELLOW}4)${NC} 重启服务"
    echo -e "${YELLOW}5)${NC} 查看实时日志"
    echo -e "${YELLOW}6)${NC} 查看配置文件"
    echo -e "${YELLOW}7)${NC} 编辑配置文件"
    echo -e "${YELLOW}8)${NC} 备份配置文件"
    echo -e "${YELLOW}9)${NC} 查看资源使用"
    echo -e "${YELLOW}10)${NC} 完全卸载"
    echo -e "${YELLOW}0)${NC} 退出"
    echo ""
}

while true; do
    show_menu
    read -p "请选择操作 (0-10): " choice
    
    case $choice in
        1)
            echo -e "${GREEN}服务状态:${NC}"
            docker compose ps
            read -p "按回车继续..."
            ;;
        2)
            echo -e "${GREEN}启动服务...${NC}"
            docker compose start
            echo -e "${GREEN}服务已启动${NC}"
            read -p "按回车继续..."
            ;;
        3)
            echo -e "${YELLOW}停止服务...${NC}"
            docker compose stop
            echo -e "${GREEN}服务已停止${NC}"
            read -p "按回车继续..."
            ;;
        4)
            echo -e "${YELLOW}重启服务...${NC}"
            docker compose restart
            echo -e "${GREEN}服务已重启${NC}"
            read -p "按回车继续..."
            ;;
        5)
            echo -e "${GREEN}实时日志 (按 Ctrl+C 退出):${NC}"
            docker compose logs -f
            ;;
        6)
            echo -e "${GREEN}配置文件内容:${NC}"
            cat config.json
            read -p "按回车继续..."
            ;;
        7)
            nano config.json
            read -p "是否重启服务应用新配置？(y/n): " restart
            if [[ $restart == "y" ]]; then
                docker compose restart
                echo -e "${GREEN}服务已重启${NC}"
            fi
            ;;
        8)
            backup_file="config.backup.$(date +%Y%m%d_%H%M%S).json"
            cp config.json "$backup_file"
            echo -e "${GREEN}配置已备份到: $backup_file${NC}"
            read -p "按回车继续..."
            ;;
        9)
            echo -e "${GREEN}资源使用情况:${NC}"
            docker stats --no-stream
            read -p "按回车继续..."
            ;;
        10)
            echo -e "${RED}警告: 此操作将删除所有数据！${NC}"
            read -p "确认卸载？(输入 yes 确认): " confirm
            if [[ "$confirm" == "yes" ]]; then
                echo -e "${YELLOW}停止服务...${NC}"
                docker compose down -v
                
                echo -e "${YELLOW}备份配置...${NC}"
                cp config.json ~/nofx_config_backup_$(date +%Y%m%d_%H%M%S).json 2>/dev/null || true
                
                echo -e "${YELLOW}删除项目...${NC}"
                cd /opt
                rm -rf nofx
                
                echo -e "${YELLOW}删除用户...${NC}"
                userdel -r nofx 2>/dev/null || true
                
                echo -e "${YELLOW}删除管理脚本...${NC}"
                rm -f /usr/local/bin/nofx
                
                echo -e "${GREEN}卸载完成${NC}"
                exit 0
            fi
            ;;
        0)
            echo -e "${GREEN}再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项${NC}"
            read -p "按回车继续..."
            ;;
    esac
done
MGMT_EOF

    chmod +x /usr/local/bin/nofx
    print_message "管理脚本已创建: /usr/local/bin/nofx ✓"
}

# ================================
# 错误处理
# ================================
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    echo "" | tee -a "$LOG_FILE"
    print_error "部署过程中发生错误！(退出代码: $exit_code, 行号: $line_number)"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${YELLOW}${BOLD}🔍 常见问题诊断${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    # Docker 相关问题
    if ! docker ps &> /dev/null; then
        echo -e "${RED}[问题] Docker 服务未运行${NC}" | tee -a "$LOG_FILE"
        echo -e "${CYAN}[解决] 运行: systemctl start docker${NC}" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    fi
    
    # 端口占用问题
    if ss -tuln 2>/dev/null | grep -q ":8080 " || netstat -tuln 2>/dev/null | grep -q ":8080 "; then
        echo -e "${RED}[问题] 端口 8080 已被占用${NC}" | tee -a "$LOG_FILE"
        echo -e "${CYAN}[解决] 查看占用进程: lsof -i :8080${NC}" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    fi
    
    if ss -tuln 2>/dev/null | grep -q ":3000 " || netstat -tuln 2>/dev/null | grep -q ":3000 "; then
        echo -e "${RED}[问题] 端口 3000 已被占用${NC}" | tee -a "$LOG_FILE"
        echo -e "${CYAN}[解决] 查看占用进程: lsof -i :3000${NC}" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    fi
    
    # 磁盘空间问题
    local available_space=$(df -BG /opt 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_space -lt 2 ]]; then
        echo -e "${RED}[问题] 磁盘空间不足 (可用: ${available_space}GB)${NC}" | tee -a "$LOG_FILE"
        echo -e "${CYAN}[解决] 清理磁盘空间${NC}" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    fi
    
    # 网络问题
    if ! ping -c 1 github.com &> /dev/null; then
        echo -e "${RED}[问题] 无法连接到 GitHub${NC}" | tee -a "$LOG_FILE"
        echo -e "${CYAN}[解决] 检查网络连接${NC}" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    fi
    
    echo -e "${YELLOW}${BOLD}📋 详细信息${NC}" | tee -a "$LOG_FILE"
    echo -e "  完整日志: ${CYAN}$LOG_FILE${NC}" | tee -a "$LOG_FILE"
    echo -e "  查看命令: ${CYAN}cat $LOG_FILE${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    echo -e "${YELLOW}${BOLD}🆘 获取帮助${NC}" | tee -a "$LOG_FILE"
    echo -e "  • GitHub Issues: ${BLUE}https://github.com/tinkle-community/nofx/issues${NC}" | tee -a "$LOG_FILE"
    echo -e "  • Twitter: ${BLUE}@hangzai${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    exit $exit_code
}

# 设置错误处理
trap 'handle_error $LINENO' ERR

# ================================
# 主函数
# ================================
main() {
    # 初始化日志文件
    echo "NOFX 安装日志 - $(date)" > "$LOG_FILE"
    echo "═══════════════════════════════════════" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # 系统检查
    check_system
    
    # 显示欢迎信息
    show_welcome
    
    # 执行部署流程
    create_nofx_user
    update_system
    install_basic_tools
    install_docker
    clone_project
    select_exchange
    guide_registration
    get_api_credentials
    create_config
    
    # 部署服务
    deploy_docker
    
    # 显示部署信息
    show_deployment_info
    
    # 记录成功安装
    echo "" >> "$LOG_FILE"
    echo "═══════════════════════════════════════" >> "$LOG_FILE"
    echo "安装成功完成于: $(date)" >> "$LOG_FILE"
    echo "═══════════════════════════════════════" >> "$LOG_FILE"
}

# ================================
# 脚本入口
# ================================

# 捕获 Ctrl+C
trap 'echo -e "\n${RED}${BOLD}部署已被用户取消${NC}"; exit 130' INT

# 捕获退出信号
trap 'echo -e "\n${YELLOW}清理完成${NC}"; exit' EXIT

# 运行主函数
main "$@"
