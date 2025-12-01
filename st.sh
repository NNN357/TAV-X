#!/bin/bash
# TAV-X Bootstrapper & Migrator (Universal)

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
export TAVX_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

CORE_FILE="$TAVX_DIR/core/main.sh"

if [ -f "$CORE_FILE" ]; then
    chmod +x "$CORE_FILE" "$TAVX_DIR"/core/*.sh "$TAVX_DIR"/modules/*.sh 2>/dev/null
    exec bash "$CORE_FILE"
else
    clear
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'

    echo -e "${RED}"
    cat << "EOF"
██╗░░░██╗██████╗░░██████╗░██████╗░░█████╗░██████╗░███████╗
██║░░░██║██╔══██╗██╔════╝░██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║░░░██║██████╔╝██║░░██╗░██████╔╝███████║██║░░██║█████╗░░
██║░░░██║██╔═══╝░██║░░╚██╗██╔══██╗██╔══██║██║░░██║██╔══╝░░
╚██████╔╝██║░░░░░╚██████╔╝██║░░██║██║░░██║██████╔╝███████╗
░╚═════╝░╚═╝░░░░░░╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═════╝░╚══════╝
EOF
    echo -e "${NC}"
    echo -e "${YELLOW}>>> 检测到 TAV-X 核心文件缺失 或 版本跨度过大。${NC}"
    echo -e "${CYAN}这通常是因为您刚刚从 v1.x 版本升级到了 v2.0 架构。${NC}"
    echo -e "v2.0 采用了全新的模块化设计，需要重新部署核心环境。"
    echo ""
    echo -e "${GREEN}不用担心，您的酒馆数据 (SillyTavern/data) 是安全的。${NC}"
    echo -e "我们即将为您自动拉取 v2.0 完整核心..."
    echo ""
    echo -e "按 ${RED}回车键 (Enter)${NC} 开始自动修复/升级..."
    read -r

    INSTALLER_URL="https://tav-x.future404.qzz.io"
    
    echo -e "${YELLOW}>>> 正在连接云端安装器...${NC}"
    
    if command -v curl &> /dev/null; then
        curl -s -L "$INSTALLER_URL" | bash
    elif command -v wget &> /dev/null; then
        wget -qO- "$INSTALLER_URL" | bash
    else
        echo -e "${RED}❌ 错误：未找到 curl 或 wget，无法自动修复。${NC}"
        echo -e "请手动执行: pkg install curl -y"
        exit 1
    fi
fi