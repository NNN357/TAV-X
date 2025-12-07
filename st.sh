#!/bin/bash
# TAV-X Universal Installer

DEFAULT_POOL=(
    "https://ghproxy.net/"
    "https://mirror.ghproxy.com/"
    "https://ghproxy.cc/"
    "https://gh.likk.cc/"
    "https://github.akams.cn/"
    "https://hub.gitmirror.com/"
    "https://hk.gh-proxy.com/"
    "https://ui.ghproxy.cc/"
    "https://gh.ddlc.top/"
    "https://gh-proxy.com/"
    "https://gh.jasonzeng.dev/"
    "https://gh.idayer.com/"
    "https://edgeone.gh-proxy.com/"
    "https://ghproxy.site/"
    "https://www.gitwarp.com/"
    "https://cors.isteed.cc/"
    "https://ghproxy.vip/"
    "https://github.com/"
)

: "${REPO_PATH:=Future-404/TAV-X.git}"
: "${TAV_VERSION:=Latest}"

if [ -n "$MIRROR_LIST" ]; then
    IFS=' ' read -r -a MIRRORS <<< "$MIRROR_LIST"
else
    MIRRORS=("${DEFAULT_POOL[@]}")
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
export TAVX_DIR="$HOME/.tav_x"
CORE_FILE="$TAVX_DIR/core/main.sh"

if [ -f "$CORE_FILE" ]; then
    chmod +x "$CORE_FILE" "$TAVX_DIR"/core/*.sh "$TAVX_DIR"/modules/*.sh 2>/dev/null
    exec bash "$CORE_FILE"
fi

clear
echo -e "${RED}"
cat << "BANNER"
██╗░░░██╗██████╗░░██████╗░██████╗░░█████╗░██████╗░███████╗
██║░░░██║██╔══██╗██╔════╝░██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║░░░██║██████╔╝██║░░██╗░██████╔╝███████║██║░░██║█████╗░░
██║░░░██║██╔═══╝░██║░░╚██╗██╔══██╗██╔══██║██║░░██║██╔══╝░░
╚██████╔╝██║░░░░░╚██████╔╝██║░░██║██║░░██║██████╔╝███████╗
░╚═════╝░╚═╝░░░░░░╚═════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═════╝░╚══════╝
BANNER
echo -e "${NC}"
echo -e "${CYAN}TAV-X 智能安装程序${NC} [Ver: ${TAV_VERSION}]"
echo "------------------------------------------------"

if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}>>> 正在安装基础依赖 (Git)...${NC}"
    pkg update -y >/dev/null 2>&1
    pkg install git -y
fi

ask_to_fix_dns() {
    echo ""
    echo -e "${RED}❌ 严重错误：核心组件下载失败。${NC}"
    echo -e "${YELLOW}🔍 诊断：无法连接 GitHub 镜像源。这通常是因为 Termux DNS 被污染。${NC}"
    echo "------------------------------------------------"
    echo -e "我们可以尝试为您将 DNS 临时修改为 ${GREEN}阿里DNS (223.5.5.5)${NC} 来解决此问题。"
    echo -e "此操作会修改 ${CYAN}$PREFIX/etc/resolv.conf${NC} 文件。"
    
    if [ -c /dev/tty ]; then
        echo -ne "${YELLOW}❓ 是否允许应用 DNS 修复补丁并重试？ [y/N]: ${NC}"
        read -r user_choice < /dev/tty
    else
        user_choice="n"
    fi
    
    if [[ "$user_choice" =~ ^[Yy]$ ]]; then
        echo -e "\n${GREEN}>>> 正在应用修复...${NC}"
        if [ -f "$PREFIX/etc/resolv.conf" ]; then
            cp "$PREFIX/etc/resolv.conf" "$PREFIX/etc/resolv.conf.bak"
        fi
        echo -e "nameserver 223.5.5.5\nnameserver 8.8.8.8" > "$PREFIX/etc/resolv.conf"
        echo -e "${GREEN}✔ DNS 已修正。正在重试下载...${NC}\n"
        return 0 
    else
        echo -e "\n${RED}>>> 用户取消操作。安装终止。${NC}"
        exit 1
    fi
}

select_best_mirror() {
    echo -e "${YELLOW}>>> 正在寻找最佳下载线路 (共 ${#MIRRORS[@]} 条)...${NC}"
    BEST_URL=""
    MIN_TIME=9999

    for mirror in "${MIRRORS[@]}"; do
        if [[ "$mirror" == *"github.com"* ]]; then
             TEST_URL="${mirror}${REPO_PATH}"
             DL_URL="${mirror}${REPO_PATH}"
        else
             TEST_URL="${mirror}https://github.com/${REPO_PATH}/info/refs?service=git-upload-pack"
             DL_URL="${mirror}https://github.com/${REPO_PATH}"
        fi
        
        TIME_START=$(date +%s%N)
        if curl -s -I -m 2 "$TEST_URL" >/dev/null 2>&1; then
            TIME_END=$(date +%s%N)
            DURATION=$(( (TIME_END - TIME_START) / 1000000 ))
            
            if [ $DURATION -lt 500 ]; then C_CODE=$GREEN; elif [ $DURATION -lt 1000 ]; then C_CODE=$YELLOW; else C_CODE=$RED; fi
            echo -e "   ⚡ ${C_CODE}${DURATION}ms${NC} | $(echo $mirror | awk -F/ '{print $3}')"
            
            if [ $DURATION -lt $MIN_TIME ]; then
                MIN_TIME=$DURATION
                BEST_URL="$DL_URL"
            fi
        else
            echo -e "   💀 ${RED}Timeout${NC} | $(echo $mirror | awk -F/ '{print $3}')"
        fi
    done
    
    if [ -z "$BEST_URL" ]; then
        echo -e "\n${RED}⚠️  所有镜像测速失败，回退至官方源重试...${NC}"
        BEST_URL="https://github.com/${REPO_PATH}"
    else
        echo -e "\n${GREEN}>>> 选中线路: $BEST_URL${NC}"
    fi
}

download_core() {
    if [ -d "$TAVX_DIR" ]; then rm -rf "$TAVX_DIR"; fi
    echo -e "${CYAN}>>> 正在拉取核心组件...${NC}"
    git clone --depth 1 "$BEST_URL" "$TAVX_DIR"
}

select_best_mirror

SUCCESS=false
if download_core; then
    SUCCESS=true
else
    if ask_to_fix_dns; then
        if download_core; then
            SUCCESS=true
        else
            echo -e "${RED}❌ 重试依然失败。请检查网络连接。${NC}"
            exit 1
        fi
    fi
fi

if [ "$SUCCESS" = true ]; then
    chmod +x "$TAVX_DIR/st.sh" "$TAVX_DIR"/core/*.sh "$TAVX_DIR"/modules/*.sh 2>/dev/null
    
    SHELL_RC="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"

    if grep -q "alias st=" "$SHELL_RC"; then
        sed -i '/alias st=/d' "$SHELL_RC"
    fi
    echo "alias st='bash $TAVX_DIR/st.sh'" >> "$SHELL_RC"

    # 安装 Gum
    if ! command -v gum &> /dev/null; then
        echo -e "${YELLOW}>>> 正在部署 UI 引擎 (Gum)...${NC}"
        pkg install gum -y >/dev/null 2>&1
    fi

    echo ""
    if command -v gum &> /dev/null; then
        gum style \
          --border double \
          --margin "1 2" \
          --padding "1 3" \
          --foreground 212 \
          --border-foreground 51 \
          "🎉 TAV-X 安装完成！"
        echo ""
        gum confirm "是否立即启动 TAV-X？" \
            --affirmative="🕒 稍后手动" \
            --negative="🕒 稍后手动" \
            --default="false" 2>/dev/null
        echo ""
        gum style \
          --border normal \
          --margin "1 2" \
          --padding "1 2" \
          --border-foreground 240 \
          "👉 必须执行以下两步：" \
          "" \
          "  1. 刷新环境: $(gum style --foreground 82 'source ~/.bashrc')" \
          "  2. 启动命令: $(gum style --foreground 212 'st')"
    
    else
        echo -e "${GREEN}🎉 TAV-X 安装成功！${NC}"
        echo -e "👉 请输入 ${CYAN}source ~/.bashrc${NC} (或重启终端) 即可生效。"
        echo -e "👉 之后输入 ${CYAN}st${NC} 即可启动。"
    fi
    echo ""
fi