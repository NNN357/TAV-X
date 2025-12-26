#!/bin/bash
# TAV-X Universal Installer

DEFAULT_POOL=(
    "https://ghproxy.net/"
    "https://mirror.ghproxy.com/"
    "https://ghproxy.cc/"
    "https://gh.likk.cc/"
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

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ -f "$SCRIPT_DIR/core/main.sh" ]; then
    echo -e "\033[1;35m🔧 [DEV MODE] Developer mode activated\033[0m"
    echo -e "📂 Using this directory as runtime: $SCRIPT_DIR"

    export TAVX_DIR="$SCRIPT_DIR"

    chmod +x "$TAVX_DIR"/core/*.sh "$TAVX_DIR"/modules/*.sh 2>/dev/null
    exec bash "$TAVX_DIR/core/main.sh"
    exit 0
fi

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
░╚═════╝░╚═╝░░░░░░╚═════╝░╚═╝░░╚═╝╚═════╝░╚══════╝
BANNER
echo -e "${NC}"
echo -e "${CYAN}TAV-X Smart Installer${NC} [Ver: ${TAV_VERSION}]"
echo "------------------------------------------------"

if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}>>> Installing base dependencies (Git)...${NC}"
    pkg update -y >/dev/null 2>&1
    pkg install git -y
fi

test_connection() {
    curl -I -s --max-time 3 "https://github.com" >/dev/null 2>&1
}

probe_direct_or_env() {
    echo -e "${YELLOW}>>> [1/3] Probing network environment...${NC}"

    if [ -n "$http_proxy" ] || [ -n "$https_proxy" ]; then
        echo -e "    Environment proxy detected: ${CYAN}${https_proxy:-$http_proxy}${NC}"
        if test_connection; then
            echo -e "${GREEN}    ✔ Proxy is working!${NC}"
            return 0
        else
            echo -e "${RED}    ✘ Environment proxy unavailable${NC}"
            unset http_proxy https_proxy all_proxy
        fi
    fi

    echo -ne "    Trying direct connection to GitHub... "
    if test_connection; then
        echo -e "${GREEN}Success${NC}"
        return 0
    else
        echo -e "${RED}Failed${NC}"
        return 1
    fi
}

probe_local_ports() {
    echo -e "\n${YELLOW}>>> [2/3] Scanning local proxy ports...${NC}"

    for entry in "${PROXY_PORTS[@]}"; do
        local port=${entry%%:*}
        local proto=${entry#*:}

        if timeout 0.2 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            echo -e "    🔍 Port found: ${CYAN}$port ($proto)${NC}"

            if [[ "$proto" == "socks5h" ]]; then
                proxy_url="socks5h://127.0.0.1:$port"
            else
                proxy_url="http://127.0.0.1:$port"
            fi

            export http_proxy="$proxy_url"
            export https_proxy="$proxy_url"
            export all_proxy="$proxy_url"

            echo -ne "    🧪 Testing proxy... "
            if test_connection; then
                echo -e "${GREEN}Available${NC}"
                return 0
            else
                echo -e "${RED}Failed${NC}"
                unset http_proxy https_proxy all_proxy
            fi
        fi
    done

    echo -e "    ⚠️ No available proxy ports found"
    return 1
}

select_mirror_interactive() {
    echo -e "\n${YELLOW}>>> [3/3] Starting mirror speed test (Smart Race)...${NC}"
    echo "------------------------------------------------"

    local tmp_race_file="/data/data/com.termux/files/usr/tmp/tav_mirror_race"
    rm -f "$tmp_race_file"
    mkdir -p "$(dirname "$tmp_race_file")"

    for mirror in "${MIRRORS[@]}"; do
        (
            if [[ "$mirror" == *"github.com"* ]]; then
                 TEST_URL="${mirror}${REPO_PATH}"
            else
                 TEST_URL="${mirror}https://github.com/${REPO_PATH}/info/refs?service=git-upload-pack"
            fi
            
            TIME_START=$(date +%s%N)
            if curl -s -I -m 3 "$TEST_URL" >/dev/null 2>&1; then
                TIME_END=$(date +%s%N)
                DURATION=$(( (TIME_END - TIME_START) / 1000000 ))
                echo "$DURATION|$mirror" >> "$tmp_race_file"
                echo -ne "."
            fi
        ) & 
    done
    wait
    echo ""
    if [ ! -s "$tmp_race_file" ]; then
        echo -e "${RED}❌ All mirrors timed out. Please check your network or toggle airplane mode.${NC}"
        exit 1
    fi

    sort -n "$tmp_race_file" -o "$tmp_race_file"

    echo "------------------------------------------------"
    echo -e " Latency(ms) | Mirror Source"
    echo "------------------------------------------------"

    VALID_URLS=()
    local idx=1
    while IFS='|' read -r dur url; do
        if [ $dur -lt 500 ]; then C_CODE=$GREEN;
        elif [ $dur -lt 1000 ]; then C_CODE=$YELLOW;
        else C_CODE=$RED; fi
        if [[ "$url" == *"github.com"* ]]; then
             DISPLAY_NAME="GitHub Official"
             DL_LINK="https://github.com/${REPO_PATH}"
        else
             DISPLAY_NAME=$(echo $url | awk -F/ '{print $3}')
             DL_LINK="${url}https://github.com/${REPO_PATH}"
        fi

        printf " [%2d] %b%4d%b | %s\n" "$idx" "$C_CODE" "$dur" "$NC" "$DISPLAY_NAME"
        
        VALID_URLS+=("$DL_LINK")
        ((idx++))
    done < "$tmp_race_file"
    rm -f "$tmp_race_file"

    echo "------------------------------------------------"
    echo -e "${CYAN}Auto-sorted by speed. Recommended: choose from top options.${NC}"
    echo -e "${CYAN}Enter number to select download source (default 1):${NC}"
    read -p ">>> " USER_CHOICE
    if [[ -z "$USER_CHOICE" ]]; then
        USER_CHOICE=1
    fi

    if [[ "$USER_CHOICE" =~ ^[0-9]+$ ]] && [ "$USER_CHOICE" -ge 1 ] && [ "$USER_CHOICE" -le "${#VALID_URLS[@]}" ]; then
        DL_URL="${VALID_URLS[$((USER_CHOICE-1))]}"
        echo -e "${GREEN}✔ Selected: $DL_URL${NC}"
    else
        echo -e "${RED}Invalid input, auto-selecting fastest mirror (option 1)${NC}"
        DL_URL="${VALID_URLS[0]}"
    fi
}

if probe_direct_or_env; then
    DL_URL="https://github.com/${REPO_PATH}"

elif probe_local_ports; then
    DL_URL="https://github.com/${REPO_PATH}"

else
    select_mirror_interactive
fi

if [ -d "$TAVX_DIR" ]; then rm -rf "$TAVX_DIR"; fi

echo -e "\n${CYAN}>>> Fetching core components...${NC}"
echo -e "Source: $DL_URL"

if git clone --depth 1 "$DL_URL" "$TAVX_DIR"; then
    chmod +x "$TAVX_DIR/st.sh" "$TAVX_DIR"/core/*.sh "$TAVX_DIR"/modules/*.sh 2>/dev/null

    SHELL_RC="$HOME/.bashrc"
    [ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"

    sed -i '/alias st=/d' "$SHELL_RC" 2>/dev/null
    echo "alias st='bash $TAVX_DIR/st.sh'" >> "$SHELL_RC"

    if ! command -v gum &> /dev/null; then
        echo -e "${YELLOW}>>> Deploying UI engine (Gum)...${NC}"
        pkg install gum -y >/dev/null 2>&1
    fi

    echo ""
    echo -e "${GREEN}🎉 TAV-X installed successfully!${NC}"
    echo -e "👉 Please run ${CYAN}source ~/.bashrc${NC} to apply, then type ${CYAN}st${NC} to start."

else
    echo -e "\n${RED}❌ Download failed${NC}"
    echo -e "Please re-run the script and select a different mirror."
    exit 1
fi