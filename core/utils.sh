#!/bin/bash
# TAV-X Core: Utilities

if [ -n "$TAVX_DIR" ] && [ -f "$TAVX_DIR/core/env.sh" ]; then
    source "$TAVX_DIR/core/env.sh"
fi


safe_rm() {
    local target="$1"
    if [[ -z "$target" ]]; then ui_print error "安全拦截: 空路径！"; return 1; fi
    if [[ "$target" == "/" ]] || [[ "$target" == "$HOME" ]] || [[ "$target" == "/usr" ]] || [[ "$target" == "/bin" ]]; then
        ui_print error "安全拦截: 高危目录 ($target)！"; return 1; fi
    if [[ "$target" == "." ]] || [[ "$target" == ".." ]]; then
        ui_print error "安全拦截: 相对路径无效！"; return 1; fi
    rm -rf "$target"
}

pause() { echo ""; read -n 1 -s -r -p "按任意键继续..."; echo ""; }

send_analytics() {
    (
        local STAT_URL="https://tav-api.future404.qzz.io"
        if command -v curl &> /dev/null; then
            curl -s -m 5 "${STAT_URL}?ver=${CURRENT_VERSION}&type=runtime" > /dev/null 2>&1
        fi
    ) &
}

safe_log_monitor() {
    local file=$1
    if [ ! -f "$file" ]; then echo "暂无日志文件: $(basename "$file")"; sleep 1; return; fi
    clear
    echo -e "${CYAN}=== 正在实时监控日志 ===${NC}"
    echo -e "${YELLOW}提示: 按 Ctrl+C 即可停止监控并返回菜单${NC}"
    echo "----------------------------------------"
    trap 'echo -e "\n${GREEN}>>> 已停止监控，正在返回...${NC}"; return' SIGINT
    tail -n 30 -f "$file"
    trap - SIGINT
}

is_port_open() {
    if timeout 0.2 bash -c "</dev/tcp/$1/$2" 2>/dev/null; then return 0; else return 1; fi
}

PROXY_PORTS_POOL=(
    "7890:socks5h" "7891:socks5h" "10809:http" "10808:socks5h" 
    "20171:http" "20170:socks5h" "9090:http" "8080:http" "1080:socks5h"
)

get_active_proxy() {
    local network_conf="$TAVX_DIR/config/network.conf"
    if [ -f "$network_conf" ]; then
        local c=$(cat "$network_conf")
        if [[ "$c" == PROXY* ]]; then
            local val=${c#*|}; val=$(echo "$val"|tr -d '\n\r')
            echo "$val"; return 0
        fi
    fi

    if [ -n "$http_proxy" ]; then echo "$http_proxy"; return 0; fi
    if [ -n "$https_proxy" ]; then echo "$https_proxy"; return 0; fi

    for entry in "${PROXY_PORTS_POOL[@]}"; do
        local port=${entry%%:*}
        local proto=${entry#*:}
        if timeout 0.1 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            if [[ "$proto" == "socks5h" ]]; then echo "socks5h://127.0.0.1:$port"; else echo "http://127.0.0.1:$port"; fi
            return 0
        fi
    done
    return 1
}

auto_load_proxy_env() {
    local proxy=$(get_active_proxy)
    if [ -n "$proxy" ]; then
        export http_proxy="$proxy"
        export https_proxy="$proxy"
        export all_proxy="$proxy"
        return 0
    else
        unset http_proxy https_proxy all_proxy
        return 1
    fi
}

find_fastest_mirror() {
    local repo_path=$1
    local tmp_race_file="$TAVX_DIR/.mirror_race"
    rm -f "$tmp_race_file"

    for mirror in "${GLOBAL_MIRRORS[@]}"; do
        (
            local start=$(date +%s%N)
            local test_url="${mirror}https://github.com/${repo_path}"
            if curl -s -I -m 3 "$test_url" >/dev/null 2>&1; then
                local end=$(date +%s%N)
                local dur=$(( (end - start) / 1000000 ))
                echo "$dur $mirror" >> "$tmp_race_file"
            fi
        ) &
    done
    wait
    
    if [ -s "$tmp_race_file" ]; then
        sort -n "$tmp_race_file" | head -n 1 | awk '{print $2}'
    fi
}

get_dynamic_proxy() {
    get_active_proxy
}

_auto_heal_network_config() {
    local network_conf="$TAVX_DIR/config/network.conf"
    local need_scan=false
    
    if [ -f "$network_conf" ]; then
        local c=$(cat "$network_conf")
        if [[ "$c" == PROXY* ]]; then
            local val=${c#*|}; val=$(echo "$val"|tr -d '\n\r')
            local p_port=$(echo "$val"|awk -F':' '{print $NF}')
            local p_host="127.0.0.1"
            [[ "$val" == *"://"* ]] && p_host=$(echo "$val"|sed -e 's|^[^/]*//||' -e 's|:.*$||')
            if ! is_port_open "$p_host" "$p_port"; then need_scan=true; fi
        fi
    else
        need_scan=true
    fi
    
    if [ "$need_scan" == "true" ]; then
        local new_proxy=$(get_active_proxy)
        if [ -n "$new_proxy" ]; then
            echo "PROXY|$new_proxy" > "$network_conf"
        fi
    fi
}

git_clone_smart() {
    local branch_arg=$1
    local raw_url=$2
    local target_dir=$3
    
    auto_load_proxy_env
    local proxy_active=$?
    
    local clean_repo=${raw_url#"https://github.com/"}
    clean_repo=${clean_repo#"git@github.com:"}

    if [ $proxy_active -eq 0 ]; then
        echo -e "${CYAN}[网络]${NC} 探测到代理加速..."
        if git clone --depth 1 $branch_arg "https://github.com/${clean_repo}" "$target_dir"; then return 0; fi
        echo -e "${YELLOW}[重试]${NC} 代理直连失败，尝试切换镜像..."
    fi

    echo -e "${BLUE}[镜像]${NC} 正在并发测速寻找最快线路..."
    local best_mirror=$(find_fastest_mirror "$clean_repo")
    
    if [ -n "$best_mirror" ]; then
        echo -e "✔ 选中: $(echo $best_mirror | awk -F/ '{print $3}')"
        if env -u http_proxy -u https_proxy git clone --depth 1 $branch_arg "${best_mirror}https://github.com/${clean_repo}" "$target_dir"; then
            return 0
        fi
    fi

    for mirror in "${GLOBAL_MIRRORS[@]}"; do
        if [ "$mirror" == "$best_mirror" ]; then continue; fi
        if curl -s -I -m 2 "${mirror}https://github.com/${clean_repo}" >/dev/null; then
             if env -u http_proxy -u https_proxy git clone --depth 1 $branch_arg "${mirror}https://github.com/${clean_repo}" "$target_dir"; then return 0; fi
        fi
    done
    
    if env -u http_proxy -u https_proxy git clone --depth 1 $branch_arg "https://github.com/${clean_repo}" "$target_dir"; then return 0; fi

    return 1
}

fix_git_remote() {
    local target_dir=$1; local repo_path=$2
    [ ! -d "$target_dir/.git" ] && return 1
    cd "$target_dir" || return 1
    
    auto_load_proxy_env
    local proxy_active=$?
    
    if [ $proxy_active -eq 0 ]; then
        echo -e "\033[1;36m[Mode]\033[0m 本地代理"
        git remote set-url origin "https://github.com/$repo_path"
        git config http.proxy "$http_proxy"
        git config https.proxy "$https_proxy"
    else
        echo -e "\033[1;36m[Mode]\033[0m 镜像加速"
        git config --unset http.proxy
        git config --unset https.proxy
        
        local best_mirror=$(find_fastest_mirror "$repo_path")
        
        if [ -n "$best_mirror" ]; then 
            echo -e "\033[0;32m✔ 选中: $best_mirror\033[0m"
            git remote set-url origin "${best_mirror}https://github.com/${repo_path}"
        else
            git remote set-url origin "https://github.com/$repo_path"
        fi
    fi
}

download_file_smart() {
    local url=$1; local filename=$2
    
    auto_load_proxy_env
    local proxy_active=$?

    if [ $proxy_active -eq 0 ]; then
        if curl -L -o "$filename" --proxy "$http_proxy" --retry 2 --max-time 60 "$url"; then return 0; fi
    fi
    
    if [[ "$url" == *"github.com"* ]]; then
        local path=${url#*github.com/}
        local best_mirror=$(find_fastest_mirror "$path") # 注意：find_fastest_mirror 主要是测 clone，这里简单复用
    fi

    local success=false
    for mirror in "${GLOBAL_MIRRORS[@]}"; do
        if [[ "$url" == *"github.com"* ]]; then
            if curl -L -o "$filename" --max-time 15 "${mirror}${url}"; then return 0; fi
        fi
    done
    
    if curl -L -o "$filename" "$url"; then return 0; else return 1; fi
}

download_file_proxy_only() {
    local url=$1; local filename=$2
    auto_load_proxy_env
    local proxy_active=$?

    if [ $proxy_active -eq 0 ]; then
        info "使用代理下载: $http_proxy"
        if curl -L -o "$filename" --proxy "$http_proxy" "$url"; then return 0; fi
        warn "代理下载失败，切换直连..."
    fi
    info "正在直连下载..."
    if curl -L -o "$filename" "$url"; then return 0; else return 1; fi
}

npm_install_smart() {
    local target_dir=${1:-.}
    cd "$target_dir" || return 1
    
    auto_load_proxy_env
    local proxy_active=$?
    
    local NPM_BASE="npm install --no-audit --no-fund --quiet --production"
    
    if [ $proxy_active -eq 0 ]; then
        npm config delete registry
        if ui_spinner "NPM 安装 (代理加速)..." "env http_proxy='$http_proxy' https_proxy='$https_proxy' $NPM_BASE"; then
            return 0
        fi
        ui_print warn "代理安装失败，切换至镜像源..."
    fi
    
    local REGISTRY_URL=""
    local SRC_CHOICE=$(ui_menu "请选择 NPM 依赖下载源" \
        "📦 淘宝源" \
        "🏫 清华源" \
        "🌐 官方源" \
        "❌ 取消安装")
    case "$SRC_CHOICE" in
        *"淘宝"*) REGISTRY_URL="https://registry.npmmirror.com" ;;
        *"清华"*) REGISTRY_URL="https://registry.npmmirror.com" ;;
        *"官方"*) REGISTRY_URL="https://registry.npmjs.org/" ;;
        *"取消"*) return 1 ;;
    esac
    npm config set registry "$REGISTRY_URL"
    if ui_spinner "NPM 安装中 ($(echo $SRC_CHOICE|awk '{print $2}')..." "$NPM_BASE"; then
        npm config delete registry
        return 0
    else
        ui_print error "依赖安装失败。"
        npm config delete registry
        return 1
    fi
}

JS_TOOL="$TAVX_DIR/scripts/config_mgr.js"

config_get() {
    local key=$1
    if [ ! -f "$JS_TOOL" ]; then return 1; fi
    node "$JS_TOOL" get "$key" 2>/dev/null
}

config_set() {
    local key=$1; local value=$2
    if [ ! -f "$JS_TOOL" ]; then
        ui_print error "找不到配置工具: $JS_TOOL"
        return 1
    fi

    local output
    output=$(node "$JS_TOOL" set "$key" "$value" 2>&1)
    local status=$?

    if [ $status -eq 0 ]; then
        return 0
    else
        ui_print error "设置失败 [$key]: $(echo "$output" | head -n 1)" 
        sleep 1
        return 1
    fi
}