#!/bin/bash
# TAV-X Universal Installer (V3.6 Active Probe & Port Sniffing)

# --- 全局配置 ---
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

PROXY_PORTS=(
    "7890:socks5h"
    "7891:socks5h"
    "10809:http"
    "10808:socks5h"
    "20171:http"
    "20170:socks5h"
    "9090:http"
    "8080:http"
    "1080:socks5h"
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

##########################################################################
#                        ★ 开发者模式自动识别 ★
##########################################################################

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ -f "$SCRIPT_DIR/core/main.sh" ]; then
    echo -e "\033[1;35m🔧 [DEV MODE] 开发者模式已激活\033[0m"
    echo -e "📂 使用此目录作为运行环境: $SCRIPT_DIR"

    export TAVX_DIR="$SCRIPT_DIR"

    chmod +x "$TAVX_DIR"/core/*.sh "$TAVX_DIR"/modules/*.sh 2>/dev/null
    exec bash "$TAVX_DIR/core/main.sh"
    exit 0
fi

##########################################################################
#                     ★ 正常生产模式（安装或启动） ★
##########################################################################

export TAVX_DIR="$HOME/.tav_x"
CORE_FILE="$TAVX_DIR/core/main.sh"

if [ -f "$CORE_FILE" ]; then
    chmod +x "$CORE_FILE" "$TAVX_DIR"/core/*.sh "$TAVX_DIR"/modules/*.sh 2>/dev/null
    exec bash "$CORE_FILE"
fi

##########################################################################
#                         以下为原版安装器逻辑
##########################################################################

clear
echo -e "${RED}"
cat << "BANNER"
██╗░░░██╗██████╗░░██████╗░██████╗░░█████╗░██████╗░███████╗
██║░░░██║██╔══██╗██╔════╝░██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║░░░██║██████╔╝██║░░██╗░██████╔╝███████║██║░░██║█████╗░░
██║░░░██║██╔═══╝░██║░░╚██╗██╔══██╗██╔══██║██║░░██║██╔══╝░░
╚██████╔╝██║░░░░░╚██████╔╝██║░░██║██║░░██║██████╔╝███████╗
░╚═════╝░╚═╝░░░░░░╚═════╝░╚═╝░░╚═╝╚═════╝░╚══════╝
BANNER
echo -e "${NC}"
echo -e "${CYAN}TAV-X 智能安装程序${NC} [Ver: ${TAV_VERSION}]"
echo "------------------------------------------------"

if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}>>> 正在安装基础依赖 (Git)...${NC}"
    pkg update -y >/dev/null 2>&1
    pkg install git -y
fi

test_connection() {
    curl -I -s --max-time 3 "https://github.com" >/dev/null 2>&1
}

probe_direct_or_env() {
    echo -e "${YELLOW}>>> [1/3] 探测现有网络环境...${NC}"

    if [ -n "$http_proxy" ] || [ -n "$https_proxy" ]; then
        echo -e "    检测到环境变量代理: ${CYAN}${https_proxy:-$http_proxy}${NC}"
        if test_connection; then
            echo -e "${GREEN}    ✔ 代理有效！${NC}"
            return 0
        else
            echo -e "${RED}    ✘ 环境变量代理不可用${NC}"
            unset http_proxy https_proxy all_proxy
        fi
    fi

    echo -ne "    尝试直连 GitHub... "
    if test_connection; then
        echo -e "${GREEN}成功${NC}"
        return 0
    else
        echo -e "${RED}失败${NC}"
        return 1
    fi
}

probe_local_ports() {
    echo -e "\n${YELLOW}>>> [2/3] 扫描本地代理端口...${NC}"

    for entry in "${PROXY_PORTS[@]}"; do
        local port=${entry%%:*}
        local proto=${entry#*:}

        if timeout 0.2 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            echo -e "    🔍 发现端口: ${CYAN}$port ($proto)${NC}"

            if [[ "$proto" == "socks5h" ]]; then
                proxy_url="socks5h://127.0.0.1:$port"
            else
                proxy_url="http://127.0.0.1:$port"
            fi

            export http_proxy="$proxy_url"
            export https_proxy="$proxy_url"
            export all_proxy="$proxy_url"

            echo -ne "    🧪 测试代理... "
            if test_connection; then
                echo -e "${GREEN}可用${NC}"
                return 0
            else
                echo -e "${RED}失败${NC}"
                unset http_proxy https_proxy all_proxy
            fi
        fi
    done

    echo -e "    ⚠️ 未发现可用代理端口"
    return 1
}

select_mirror_interactive() {
    echo -e "\n${YELLOW}>>> [3/3] 启动镜像测速...${NC}"
    echo "------------------------------------------------"

    VALID_URLS=()
    local idx=1

    for mirror in "${MIRRORS[@]}"; do
        if [[ "$mirror" == *"github.com"* ]]; then
             TEST_URL="${mirror}${REPO_PATH}"
             DL_URL="${mirror}${REPO_PATH}"
             DISPLAY_NAME="GitHub 官方"
        else
             TEST_URL="${mirror}https://github.com/${REPO_PATH}/info/refs?service=git-upload-pack"
             DL_URL="${mirror}https://github.com/${REPO_PATH}"
             DISPLAY_NAME=$(echo $mirror | awk -F/ '{print $3}')
        fi

        TIME_START=$(date +%s%N)
        if curl -s -I -m 2 "$TEST_URL" >/dev/null 2>&1; then
            TIME_END=$(date +%s%N)
            DURATION=$(( (TIME_END - TIME_START) / 1000000 ))

            if [ $DURATION -lt 500 ]; then C_CODE=$GREEN;
            elif [ $DURATION -lt 1000 ]; then C_CODE=$YELLOW;
            else C_CODE=$RED; fi

            printf " [%2d] %b%4dms%b | %s\n" "$idx" "$C_CODE" "$DURATION" "$NC" "$DISPLAY_NAME"
            VALID_URLS+=("$DL_URL")
            ((idx++))
        else
            echo -e " [XX] ${RED}Timeout${NC} | $DISPLAY_NAME"
        fi
    done

    echo "------------------------------------------------"

    if [ ${#VALID_URLS[@]} -eq 0 ]; then
        echo -e "${RED}❌ 所有线路均不可用${NC}"
        exit 1
    fi

    echo -e "${CYAN}输入序号选择下载源：${NC}"
    read -p ">>> " USER_CHOICE

    if [[ "$USER_CHOICE" =~ ^[0-9]+$ ]] && [ "$USER_CHOICE" -ge 1 ] && [ "$USER_CHOICE" -le "${#VALID_URLS[@]}" ]; then
        DL_URL="${VALID_URLS[$((USER_CHOICE-1))]}"
        echo -e "${GREEN}✔ 已选择: $DL_URL${NC}"
    else
        echo -e "${RED}无效输入，默认第一项${NC}"
        DL_URL="${VALID_URLS[0]}"
    fi
}

########################################################
# 主逻辑：选择下载方式
########################################################

if probe_direct_or_env; then
    DL_URL="https://github.com/${REPO_PATH}"

elif probe_local_ports; then
    DL_URL="https://github.com/${REPO_PATH}"

else
    select_mirror_interactive
fi

########################################################
# 执行下载并安装
########################################################

if [ -d "$TAVX_DIR" ]; then rm -rf "$TAVX_DIR"; fi

echo -e "\n${CYAN}>>> 正在拉取核心组件...${NC}"
echo -e "源地址: $DL_URL"

if git clone --depth 1 "$DL_URL" "$TAVX_DIR"; then
    chmod +x "$TAVX_DIR/st.sh" "$TAVX_DIR"/core/*.sh "$TAVX_DIR"/modules/*.sh 2>/dev/null

    SHELL_RC="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"

    sed -i '/alias st=/d' "$SHELL_RC" 2>/dev/null
    echo "alias st='bash $TAVX_DIR/st.sh'" >> "$SHELL_RC"

    if ! command -v gum &> /dev/null; then
        echo -e "${YELLOW}>>> 部署 UI 引擎 (Gum)...${NC}"
        pkg install gum -y >/dev/null 2>&1
    fi

    echo ""
    echo -e "${GREEN}🎉 TAV-X 安装成功！${NC}"
    echo -e "👉 请输入 ${CYAN}source ~/.bashrc${NC} 生效，然后输入 ${CYAN}st${NC} 启动。"

else
    echo -e "\n${RED}❌ 下载失败${NC}"
    echo -e "请重新运行脚本并选择其他线路。"
    exit 1
fi