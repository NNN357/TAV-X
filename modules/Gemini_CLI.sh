#!/bin/bash
# [METADATA]
# MODULE_NAME: ♊ Gemini CLI Proxy
# MODULE_ENTRY: gemini_menu
# [END_METADATA]
source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

GEMINI_DIR="$TAVX_DIR/gemini_proxy"
VENV_DIR="$GEMINI_DIR/venv"
VENV_PYTHON="$VENV_DIR/bin/python"
VENV_PIP="$VENV_DIR/bin/pip"
REPO_URL="gzzhongqi/geminicli2api"
CREDS_FILE="$GEMINI_DIR/oauth_creds.json"
ENV_FILE="$GEMINI_DIR/.env"
LOG_FILE="$GEMINI_DIR/service.log"
TUNNEL_LOG="$GEMINI_DIR/tunnel.log"

get_proxy_address() {
    get_active_proxy
}

check_google_connectivity() {
    local timeout_sec=5
    local target_url="https://www.google.com"
    local proxy=$(get_proxy_address)
    
    ui_print info "Checking Google connectivity..."
    
    local cmd="curl -I -s --max-time $timeout_sec"
    local proxy_msg="Direct"
    
    if [ -n "$proxy" ]; then
        cmd="$cmd --proxy '$proxy'"
        proxy_msg="Proxy ($proxy)"
    fi
    
    if eval "$cmd '$target_url'" >/dev/null 2>&1; then
        return 0
    else
        ui_print error "Google connection failed! Mode: $proxy_msg"
        echo -e "${YELLOW}Possible causes:${NC}"
        echo -e "1. Proxy not configured (Gemini requires VPN/proxy)."
        echo -e "2. Proxy node unstable or doesn't support UDP/TCP."
        echo -e "3. Network timeout."
        echo ""
        if ui_confirm "Go to network settings to configure?"; then
            configure_download_network
        fi
        return 1
    fi
}

pip_install_smart() {
    local pip_cmd="$1"; shift; local args="$@"
    local proxy=$(get_proxy_address); local success=false

    export CARGO_BUILD_JOBS=1
    export CC=clang
    export CXX=clang++
    export CFLAGS="-Wno-implicit-function-declaration"

    args="$args -v"

    if [ -n "$proxy" ]; then
        ui_print info "Downloading dependencies via proxy..."
        if env http_proxy="$proxy" https_proxy="$proxy" $pip_cmd $args; then success=true; else ui_print warn "Proxy download failed, trying China mirrors..."; fi
    fi

    if [ "$success" = false ]; then
        local mirrors=("https://pypi.tuna.tsinghua.edu.cn/simple" "https://mirrors.aliyun.com/pypi/simple/")
        for mirror in "${mirrors[@]}"; do
            ui_print info "Trying mirror: $(echo $mirror | awk -F/ '{print $3}')"
            if env -u http_proxy -u https_proxy $pip_cmd $args -i "$mirror"; then success=true; break; fi
        done
    fi
    
    unset CARGO_BUILD_JOBS CC CXX CFLAGS
    
    if [ "$success" = true ]; then return 0; else ui_print error "Dependency installation failed (compile error)."; return 1; fi
}

check_auth_dependencies() {
    local missing=""
    command -v stdbuf >/dev/null || missing="$missing coreutils"
    
    if [ -n "$missing" ]; then
        ui_print info "Installing auth dependencies: $missing"
        pkg install $missing -y
    fi
}

install_gemini() {
    ui_header "Deploy Gemini Proxy Service"
    
    cd "$TAVX_DIR" || exit 1

    local NEED_PKGS=""
    if ! command -v python &> /dev/null; then NEED_PKGS="$NEED_PKGS python"; fi
    if ! command -v rustc &> /dev/null; then NEED_PKGS="$NEED_PKGS rust"; fi
    if ! command -v ar &> /dev/null; then NEED_PKGS="$NEED_PKGS binutils"; fi
    if ! command -v clang &> /dev/null; then NEED_PKGS="$NEED_PKGS clang"; fi
    if ! command -v make &> /dev/null; then NEED_PKGS="$NEED_PKGS make"; fi
    if ! command -v cmake &> /dev/null; then NEED_PKGS="$NEED_PKGS cmake"; fi
    if ! command -v cloudflared &> /dev/null; then NEED_PKGS="$NEED_PKGS cloudflared"; fi

    if [ -n "$NEED_PKGS" ]; then 
        ui_print info "Pre-installing build environment..."
        echo -e "${CYAN}Installing: $NEED_PKGS${NC}"
        pkg update -y
        pkg install $NEED_PKGS -y
    fi
    
    check_auth_dependencies

    safe_rm "$GEMINI_DIR"
    
    prepare_network_strategy "$REPO_URL"

    local CLONE_CMD="source \"$TAVX_DIR/core/utils.sh\"; git_clone_smart '' '$REPO_URL' '$GEMINI_DIR'"
    if ! ui_spinner "Downloading source code..." "$CLONE_CMD"; then ui_print error "Source download failed."; ui_pause; return 1; fi

    cd "$GEMINI_DIR" || return

    ui_print info "Creating Python virtual environment..."
    python -m venv venv || { ui_print error "Venv creation failed"; ui_pause; return 1; }

    ui_print info "Compiling and installing dependencies..."
    echo -e "${YELLOW}⚠️ Note: This may take a while, keep screen on!${NC}"
    
    pip_install_smart "$VENV_PIP" install --upgrade pip --no-cache-dir
    
    # SOCKS support for Python requests
    ui_print info "Pre-installing SOCKS proxy support..."
    if ! pip_install_smart "$VENV_PIP" install "requests[socks]" "PySocks" --no-cache-dir; then
        ui_print warn "SOCKS library installation had issues, continuing with main deps..."
    fi
    
    if pip_install_smart "$VENV_PIP" install -r requirements.txt --no-cache-dir; then
        echo "HOST=0.0.0.0" > "$ENV_FILE"
        echo "PORT=8888" >> "$ENV_FILE"
        echo "GEMINI_AUTH_PASSWORD=password" >> "$ENV_FILE"
        ui_print success "Gemini service deployed successfully!"
    else
        ui_print error "Critical: Dependency compilation failed."
        echo -e "${YELLOW}Please try running 'pkg upgrade' to update system libraries and retry.${NC}"
        ui_pause; return 1
    fi
    ui_pause
}

ensure_installed() {
    if [ ! -d "$GEMINI_DIR" ]; then
        ui_print warn "Gemini module not installed."
        echo -e "${YELLOW}Core components need to be downloaded first.${NC}"
        echo ""
        if ui_confirm "Start installation now?"; then
            install_gemini
            if [ ! -d "$GEMINI_DIR" ]; then return 1; fi
        else
            ui_print info "Operation cancelled."; return 1
        fi
    fi
    return 0
}

authenticate_google() {
    ensure_installed || return
    check_google_connectivity || return
    check_auth_dependencies

    if [ -f "$CREDS_FILE" ]; then
        ui_print warn "Existing login credentials detected!"
        if ! ui_confirm "Re-authenticating will overwrite existing file, continue?"; then return; fi
        rm -f "$CREDS_FILE"
    fi

    ui_header "Google Account Authorization"
    echo -e "${CYAN}Process:${NC}"
    echo -e "1. Script will generate auth link in background."
    echo -e "2. If browser doesn't open automatically, go to [📜 View Logs] to copy link."
    echo -e "3. After logging in via browser, come back and click [🚀 Start Service]."
    echo ""
    
    local proxy=$(get_proxy_address)
    local proxy_env=""
    [ -n "$proxy" ] && proxy_env="http_proxy=$proxy https_proxy=$proxy"

    cd "$GEMINI_DIR" || return
    
    rm -f "$LOG_FILE"
    pkill -f "$VENV_PYTHON run.py"

    echo -e "${GREEN}>>> Starting auth process in background...${NC}"
    nohup env -u GEMINI_CREDENTIALS \
        GEMINI_AUTH_PASSWORD="init" \
        PYTHONUNBUFFERED=1 \
        $proxy_env \
        "$VENV_PYTHON" -u run.py > "$LOG_FILE" 2>&1 &
    
    local APP_PID=$!
    local CRASHED=0

    echo -ne "Getting link..."
    local url=""
    for i in {1..10}; do
        if ! kill -0 $APP_PID 2>/dev/null; then CRASHED=1; break; fi
        if grep -q "https://accounts.google.com" "$LOG_FILE"; then
            url=$(grep -o "https://accounts.google.com[^\ ]*" "$LOG_FILE" | head -n 1 | tr -d '\r\n')
            break
        fi
        echo -ne "."
        sleep 1
    done
    echo ""

    if [ $CRASHED -eq 1 ]; then
        ui_print error "Auth process crashed unexpectedly!"
        echo -e "${YELLOW}--- Error Log (last 10 lines) ---${NC}"
        tail -n 10 "$LOG_FILE"
        echo -e "${YELLOW}----------------------------${NC}"
        ui_pause; return
    fi

    if [ -n "$url" ]; then
        termux-open "$url" 2>/dev/null
        ui_print success "Browser opened! Please log in."
    else
        ui_print info "Could not auto-get link."
        echo -e "${YELLOW}Please manually go to Main Menu -> [📜 View Logs] to copy link.${NC}"
    fi
    
    echo -e "------------------------------------------------"
    echo -e "✅ Next step: After logging in via browser, come back and click [🚀 Start Service]."
    
    ui_pause
}

start_tunnel() {
    ensure_installed || return
    
    if ! pgrep -f "$VENV_PYTHON run.py" >/dev/null; then
        ui_print error "Gemini service not running!"
        echo -e "Please click [🚀 Start/Restart Service] first."
        ui_pause; return
    fi

    local port=$(grep "^PORT=" "$ENV_FILE" 2>/dev/null | cut -d= -f2); [ -z "$port" ] && port=8888
    local token_file="$TAVX_DIR/config/cf_token"
    local proxy=$(get_proxy_address)
    
    ui_header "Cloudflare Remote Tunnel"
    
    pkill -f "cloudflared tunnel"
    rm -f "$TUNNEL_LOG"

    if [ -f "$token_file" ] && [ -s "$token_file" ]; then
        local token=$(cat "$token_file")
        ui_print info "Fixed Token detected, starting fixed tunnel..."
        
        if [ -n "$proxy" ]; then
            setsid env TUNNEL_HTTP_PROXY="$proxy" nohup cloudflared tunnel run --token "$token" > "$TUNNEL_LOG" 2>&1 &
        else
            setsid nohup cloudflared tunnel run --token "$token" > "$TUNNEL_LOG" 2>&1 &
        fi
        
        sleep 3
        if pgrep -f "cloudflared" >/dev/null; then
            ui_print success "Fixed tunnel started!"
            echo -e "Please visit your custom domain."
        else
            ui_print error "Start failed, please check logs."
        fi
        
    else
        ui_print info "Starting temporary tunnel (TryCloudflare)..."
        local cf_cmd="tunnel --url http://localhost:$port --no-autoupdate"
        
        if [ -n "$proxy" ]; then
            setsid env TUNNEL_HTTP_PROXY="$proxy" nohup cloudflared $cf_cmd --protocol http2 > "$TUNNEL_LOG" 2>&1 &
        else
            setsid nohup cloudflared $cf_cmd > "$TUNNEL_LOG" 2>&1 &
        fi
        
        echo -ne "Getting link..."
        local link=""
        for i in {1..15}; do
            if grep -q "trycloudflare.com" "$TUNNEL_LOG"; then
                link=$(grep -o "https://[-a-zA-Z0-9]*\.trycloudflare\.com" "$TUNNEL_LOG" | grep -v "api" | tail -n 1)
                if [ -n "$link" ]; then break; fi
            fi
            echo -ne "."
            sleep 1
        done
        echo ""
        
        if [ -n "$link" ]; then
            ui_print success "Tunnel created!"
            echo -e "\n${YELLOW}👉 $link${NC}\n"
            echo -e "${CYAN}(Long press to copy, use as API URL in remote tavern)${NC}"
        else
            ui_print error "Link retrieval timeout. Check network or proxy settings."
        fi
    fi
    ui_pause
}

stop_tunnel() {
    pkill -f "cloudflared tunnel"
    ui_print success "Remote tunnel closed."
    sleep 1
}

start_service() {
    ensure_installed || return
    check_google_connectivity || return
    
    local port=$(grep "^PORT=" "$ENV_FILE" 2>/dev/null | cut -d= -f2); [ -z "$port" ] && port=8888

    pkill -f "$VENV_PYTHON run.py"
    pkill -f "cloudflared tunnel"
    
    if command -v fuser >/dev/null; then
        fuser -k -9 "$port/tcp" >/dev/null 2>&1
    elif command -v lsof >/dev/null; then
        local pid=$(lsof -t -i:"$port")
        if [ -n "$pid" ]; then kill -9 $pid >/dev/null 2>&1; fi
    fi
    sleep 1

    if [ ! -f "$CREDS_FILE" ]; then
        if ls "$GEMINI_DIR"/*creds*.json 1> /dev/null 2>&1; then
            mv "$GEMINI_DIR"/*creds*.json "$CREDS_FILE" 2>/dev/null
            ui_print success "New credentials detected, auto-applied!"
        else
            ui_print error "No authorization credentials found."
            echo -e "Please run [🔑 Google Account Authorization] and complete browser login first."
            ui_pause; return
        fi
    fi

    local pass=$(grep "^GEMINI_AUTH_PASSWORD=" "$ENV_FILE" 2>/dev/null | cut -d= -f2); [ -z "$pass" ] && pass="password"
    
    if grep -q "^PORT=" "$ENV_FILE"; then sed -i "s/^PORT=.*/PORT=$port/" "$ENV_FILE"; else echo "PORT=$port" >> "$ENV_FILE"; fi
    if grep -q "^GEMINI_AUTH_PASSWORD=" "$ENV_FILE"; then sed -i "s/^GEMINI_AUTH_PASSWORD=.*/GEMINI_AUTH_PASSWORD=$pass/" "$ENV_FILE"; else echo "GEMINI_AUTH_PASSWORD=$pass" >> "$ENV_FILE"; fi
    
    if ! grep -q "^GEMINI_CREDENTIALS=" "$ENV_FILE"; then
        echo -n "GEMINI_CREDENTIALS='" >> "$ENV_FILE"
        cat "$CREDS_FILE" >> "$ENV_FILE"
        echo "'" >> "$ENV_FILE"
    fi

    local proxy=$(get_proxy_address); local proxy_env=""
    [ -n "$proxy" ] && proxy_env="env http_proxy='$proxy' https_proxy='$proxy' all_proxy='$proxy'"
    
    ui_header "Start Service"
    cd "$GEMINI_DIR" || return
    local START_CMD="$proxy_env GEMINI_AUTH_PASSWORD='$pass' setsid nohup $VENV_PYTHON run.py > '$LOG_FILE' 2>&1 &"
    
    if ui_spinner "Starting service..." "eval \"$START_CMD\" sleep 3"; then
        if pgrep -f "run.py" >/dev/null; then
            ui_print success "Service started! Port: $port"
        else
            ui_print error "Start failed, process exited immediately."
            echo -e "${YELLOW}--- Error Log ---${NC}"
            tail -n 5 "$LOG_FILE"
            echo -e "${YELLOW}---------------${NC}"
        fi
    else ui_print error "Start timeout."; fi
    ui_pause
}

stop_service() {
    pkill -f "$VENV_PYTHON run.py"
    pkill -f "cloudflared tunnel"
    ui_print success "Service and tunnel stopped."
    sleep 1
}

show_info() {
    local port=$(grep "^PORT=" "$ENV_FILE" 2>/dev/null | cut -d= -f2); [ -z "$port" ] && port=8888
    local pass=$(grep "^GEMINI_AUTH_PASSWORD=" "$ENV_FILE" 2>/dev/null | cut -d= -f2); [ -z "$pass" ] && pass="password"
    local proj=$(grep "^GOOGLE_CLOUD_PROJECT=" "$ENV_FILE" 2>/dev/null | cut -d= -f2); [ -z "$proj" ] && proj="Not Set (Auto)"
    
    ui_header "Connection Info"
    
    local tunnel_url=""
    if pgrep -f "cloudflared" >/dev/null; then
        if [ -s "$TAVX_DIR/config/cf_token" ]; then
            tunnel_url="Use your custom domain"
        elif [ -f "$TUNNEL_LOG" ]; then
            tunnel_url=$(grep -o "https://[-a-zA-Z0-9]*\.trycloudflare\.com" "$TUNNEL_LOG" | grep -v "api" | tail -n 1)
        fi
    fi

    echo -e "${YELLOW}Enter this info in SillyTavern or other AI clients:${NC}\n"
    
    if [ -n "$tunnel_url" ]; then
        echo -e "${GREEN}🌍 Public Remote URL (Cloudflare):${NC}"
        echo -e "   $tunnel_url/v1"
        echo ""
    fi

    echo -e "🏠 Local LAN Address:"
    echo -e "   http://127.0.0.1:$port/v1"
    echo ""
    echo -e "🔑 API Key (Password):"
    echo -e "   $pass"
    echo ""
    echo -e "🆔 Google Cloud Project ID:"
    echo -e "   $proj"
    
    ui_pause
}

configure_params() {
    if [ ! -f "$ENV_FILE" ]; then touch "$ENV_FILE"; fi
    local port=$(grep "^PORT=" "$ENV_FILE" | cut -d= -f2); [ -z "$port" ] && port=8888
    local pass=$(grep "^GEMINI_AUTH_PASSWORD=" "$ENV_FILE" | cut -d= -f2); [ -z "$pass" ] && pass="password"
    local proj=$(grep "^GOOGLE_CLOUD_PROJECT=" "$ENV_FILE" | cut -d= -f2); [ -z "$proj" ] && proj="Not Set (Auto)"
    
    while true; do
        ui_header "Parameter Settings"
        echo -e "Port: $port | Password: $pass"
        echo -e "Project ID: $proj"
        echo ""
        
        CHOICE=$(ui_menu "Select to modify" "🆔 Modify Project ID" "🔌 Modify Port" "🔑 Modify Password" "🔙 Back")
        case "$CHOICE" in
            *"Project ID"*)
                echo -e "${CYAN}Tip: Enter your Google Cloud Project ID (e.g., my-project-123)${NC}"
                echo -e "${YELLOW}Leave empty to use auto-detect mode.${NC}"
                new_id=$(ui_input "Enter Project ID" "$proj" "false")
                
                if [ -n "$new_id" ] && [ "$new_id" != "Not Set (Auto)" ]; then
                    if grep -q "^GOOGLE_CLOUD_PROJECT=" "$ENV_FILE"; then
                        sed -i "s/^GOOGLE_CLOUD_PROJECT=.*/GOOGLE_CLOUD_PROJECT=$new_id/" "$ENV_FILE"
                    else
                        echo "GOOGLE_CLOUD_PROJECT=$new_id" >> "$ENV_FILE"
                    fi
                    proj=$new_id
                    ui_print success "Project ID saved!"
                else
                    sed -i '/^GOOGLE_CLOUD_PROJECT=/d' "$ENV_FILE"
                    proj="Not Set (Auto)"
                    ui_print info "Restored to auto-detect mode."
                fi
                ui_pause
                ;;
            *"Port"*) 
                p=$(ui_input "Enter new port" "$port" "false")
                if [[ "$p" =~ ^[0-9]+$ ]]; then 
                    if grep -q "^PORT=" "$ENV_FILE"; then sed -i "s/^PORT=.*/PORT=$p/" "$ENV_FILE"; else echo "PORT=$p" >> "$ENV_FILE"; fi
                    port=$p; ui_print success "Saved (restart to apply)"
                fi ;;
            *"Password"*) 
                p=$(ui_input "Enter new password" "$pass" "false")
                if [ -n "$p" ]; then 
                    if grep -q "^GEMINI_AUTH_PASSWORD=" "$ENV_FILE"; then sed -i "s/^GEMINI_AUTH_PASSWORD=.*/GEMINI_AUTH_PASSWORD=$p/" "$ENV_FILE"; else echo "GEMINI_AUTH_PASSWORD=$p" >> "$ENV_FILE"; fi
                    pass=$p; ui_print success "Saved (restart to apply)"
                fi ;;
            *"Back"*) return ;;
        esac
    done
}

gemini_menu() {
    while true; do
        ui_header "Gemini 2.0 Smart Proxy"
        local s="${RED}● Stopped${NC}"; pgrep -f "$VENV_PYTHON run.py" >/dev/null && s="${GREEN}● Running${NC}"
        local cf="${RED}Off${NC}"; pgrep -f "cloudflared" >/dev/null && cf="${GREEN}On${NC}"
        local a="${YELLOW}Not Authorized${NC}"; [ -f "$CREDS_FILE" ] && a="${GREEN}Authorized${NC}"
        
        echo -e "Status: $s | Tunnel: $cf | Auth: $a"
        echo "----------------------------------------"

        CHOICE=$(ui_menu "Select action" \
            "🚀 Start/Restart Service" \
            "🌍 Toggle Remote Tunnel" \
            "🔑 Google Account Authorization" \
            "📥 Install/Reinstall Service" \
            "📝 View Connection Info" \
            "⚙️  Configure Parameters" \
            "📜 View Logs" \
            "🛑 Stop All Services" \
            "🔙 Back"
        )
        case "$CHOICE" in
            *"Start"*) start_service ;;
            *"Remote Tunnel"*) 
                if pgrep -f "cloudflared" >/dev/null; then stop_tunnel; else start_tunnel; fi ;;
            *"Authorization"*) authenticate_google ;;
            *"Install"*) install_gemini ;;
            *"Connection Info"*) show_info ;;
            *"Configure"*) configure_params ;;
            *"Logs"*) safe_log_monitor "$LOG_FILE" ;;
            *"Stop"*) stop_service ;;
            *"Back"*) return ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then gemini_menu; fi