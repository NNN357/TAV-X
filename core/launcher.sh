#!/bin/bash

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"
source "$TAVX_DIR/core/install.sh"

CF_LOG="$INSTALL_DIR/cf_tunnel.log"
SERVER_LOG="$INSTALL_DIR/server.log"
NETWORK_CONFIG="$TAVX_DIR/config/network.conf"
MEMORY_CONFIG="$TAVX_DIR/config/memory.conf"

get_active_port() {
    local port=8000
    local cfg_port=$(config_get port)
    if [[ "$cfg_port" =~ ^[0-9]+$ ]]; then
        port="$cfg_port"
    fi
    echo "$port"
}

get_memory_args() {
    if [ -f "$MEMORY_CONFIG" ]; then
        local mem=$(cat "$MEMORY_CONFIG")
        if [[ "$mem" =~ ^[0-9]+$ ]] && [ "$mem" -gt 0 ]; then
            echo "--max-old-space-size=$mem"
        fi
    fi
}

get_smart_proxy_url() {
    if [ -f "$NETWORK_CONFIG" ]; then
        local c=$(cat "$NETWORK_CONFIG"); local t=${c%%|*}; local v=${c#*|}
        v=$(echo "$v"|tr -d '\n\r')
        if [ "$t" == "PROXY" ]; then
            echo "$v"
        fi
    fi
}

apply_recommended_settings() {
    ui_print info "Applying recommended settings..."
    
    local BATCH_JSON='{
        "listen": true,
        "whitelistMode": false,
        "basicAuthMode": false,
        "ssl.enabled": false,
        "hostWhitelist.enabled": false,
        "enableUserAccounts": true,
        "enableDiscreetLogin": true,
        "extensions.enabled": true,
        "enableServerPlugins": true,
        "performance.useDiskCache": false,
        "performance.lazyLoadCharacters": true
    }'
    
    if config_set_batch "$BATCH_JSON"; then
        ui_print success "Recommended settings applied!"
    else
        ui_print error "Failed to apply settings, please check logs."
    fi
    sleep 1
}

check_install_integrity() {
    if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/server.js" ]; then
        ui_print error "SillyTavern core files not detected."
        if ui_confirm "Run installation repair now?"; then 
            install_sillytavern
            return 0
        else return 1; fi
    fi
    return 0
}

stop_services() {
    local PORT=$(get_active_port)
    pkill -f "node server.js"
    pkill -f "cloudflared"
    termux-wake-unlock 2>/dev/null
    
    local wait_count=0
    while pgrep -f "node server.js" > /dev/null; do
        if [ "$wait_count" -eq 0 ]; then ui_print info "Stopping old processes..."; fi
        sleep 0.5
        ((wait_count++))
        if [ "$wait_count" -ge 10 ]; then 
            ui_print warn "Process not responding, force killing..."
            pkill -9 -f "node server.js"
        fi
        if [ "$wait_count" -ge 20 ]; then break; fi
    done
    sleep 1
}

start_node_server() {
    local MEM_ARGS=$(get_memory_args)
    cd "$INSTALL_DIR" || return 1
    termux-wake-lock
    rm -f "$SERVER_LOG"
    ui_spinner "Starting SillyTavern service..." "setsid nohup node $MEM_ARGS server.js > '$SERVER_LOG' 2>&1 & sleep 3"
    
    if ! pgrep -f "node server.js" > /dev/null; then
         ui_print error "Service crashed immediately! (Missing dependencies?)"
         echo -e "${YELLOW}=== Crash Log (Last 10 lines) ===${NC}"
         tail -n 10 "$SERVER_LOG"
         echo -e "${YELLOW}=================================${NC}"
         echo -e "Tip: Try [Install & Update] -> [Force Reinstall] to fix."
    fi
}

detect_protocol_logic() {
    local proxy=$1
    if [ -n "$proxy" ]; then echo "http2"; return; fi
    local t1="www.cloudflare.com"; local count=0
    if ping -c 1 -W 1 "$t1" >/dev/null 2>&1; then count=1; fi
    local udp_ok=0; timeout 1 nc -u -z -w 1 quic.cloudflare.com 7844 2>/dev/null && udp_ok=1
    if [ "$udp_ok" -eq 1 ]; then echo "quic"; else echo "http2"; fi
}

wait_for_link_logic() {
    local max=15; local count=0
    while [ $count -le $max ]; do
        if [ -f "$CF_LOG" ]; then
            local link=$(grep -o "https://[-a-zA-Z0-9]*\.trycloudflare\.com" "$CF_LOG" | grep -v "api.trycloudflare.com" | tail -n 1)
            if [ -n "$link" ]; then echo "$link"; return 0; fi
        fi
        sleep 1
        ((count++))
    done
    return 1
}

start_fixed_tunnel() {
    local PORT=$1; local PROXY_URL=$2; local CF_TOKEN=$3
    local CF_CMD="tunnel run --token $CF_TOKEN"
    
    if [ -n "$PROXY_URL" ]; then
        ui_print info "Proxy injected: $PROXY_URL"
        setsid env TUNNEL_HTTP_PROXY="$PROXY_URL" nohup cloudflared $CF_CMD --protocol http2 > "$CF_LOG" 2>&1 &
    else
        setsid nohup cloudflared $CF_CMD > "$CF_LOG" 2>&1 &
    fi
    
    ui_print success "Service started!"
    echo ""
    echo -e "${GREEN}Please visit the domain you bound in Cloudflare dashboard.${NC}"
    echo -e "${GRAY}(Fixed tunnel doesn't need temporary link)${NC}"
}

start_temp_tunnel() {
    local PORT=$1; local PROXY_URL=$2
    local PROTOCOL="http2"
    if [ -n "$PROXY_URL" ]; then
        ui_print info "Proxy detected, forcing HTTP2..."
    else
        PROTOCOL=$(detect_protocol_logic "")
    fi
    
    local CF_ARGS=(tunnel --protocol "$PROTOCOL" --url "http://127.0.0.1:$PORT" --no-autoupdate)
    
    if [ -n "$PROXY_URL" ]; then
        ui_print info "Tunnel connected via proxy: $PROXY_URL"
        setsid env TUNNEL_HTTP_PROXY="$PROXY_URL" nohup cloudflared "${CF_ARGS[@]}" > "$CF_LOG" 2>&1 &
    else
        setsid nohup cloudflared "${CF_ARGS[@]}" > "$CF_LOG" 2>&1 &
    fi
    
    rm -f "$TAVX_DIR/.temp_link"
    local wait_cmd="source \"$TAVX_DIR/core/launcher.sh\"; link=\$(wait_for_link_logic); if [ -n \"\$link\" ]; then echo \"\$link\" > \"$TAVX_DIR/.temp_link\"; exit 0; else exit 1; fi"
    
    if ui_spinner "Establishing tunnel ($PROTOCOL)..." "$wait_cmd"; then
        local LINK=$(cat "$TAVX_DIR/.temp_link")
        ui_print success "Link created successfully!"
        echo ""
        echo -e "${YELLOW}👉 $LINK${NC}"
        echo ""
        echo -e "${CYAN}(Long press to copy)${NC}"
    else 
        ui_print error "Link retrieval timed out."
        ui_print warn "Tip: If it keeps timing out, try toggling VPN on/off and retry."
    fi
}

start_menu() {
    check_install_integrity || return
    local PORT=$(get_active_port)

    while true; do
        _auto_heal_network_config
        local PROXY_URL=$(get_smart_proxy_url)
        local MEM_ARGS=$(get_memory_args)
        
        local status_txt=""
        if pgrep -f "cloudflared" >/dev/null; then 
            if grep -q "protocol=quic" "$CF_LOG" 2>/dev/null; then P="QUIC"; else P="HTTP2"; fi
            status_txt="${GREEN}● Tunnel Running ($P)${NC}"
        elif pgrep -f "node server.js" >/dev/null; then 
            status_txt="${GREEN}● Running Locally${NC}"
        else status_txt="${RED}● Stopped${NC}"; fi
        
        [ -n "$PROXY_URL" ] && status_txt="$status_txt ${CYAN}[Proxy Active]${NC}"
        local MEM_SHOW=""
        if [ -n "$MEM_ARGS" ]; then MEM_SHOW=" | 🧠 $(echo $MEM_ARGS | cut -d'=' -f2)MB"; fi

        ui_header "Launch Center (Port: $PORT$MEM_SHOW)"
        echo -e "Status: $status_txt"
        echo ""

        CHOICE=$(ui_menu "Select action" "🏠 Start Local Mode" "🌍 Start Remote Tunnel" "🔍 Get Remote Link" "⚡ Apply Recommended Settings" "📜 Monitor Logs" "🛑 Stop All Services" "🔙 Back to Main Menu")

        case "$CHOICE" in
            *"Local Mode"*) 
                stop_services
                start_node_server
                local PORT=$(get_active_port)
                ui_print success "Local started: http://127.0.0.1:$PORT"
                ui_pause ;;
                
            *"Remote Tunnel"*) 
                stop_services
                start_node_server
                rm -f "$CF_LOG"
                local PORT=$(get_active_port); local PROXY_URL=$(get_smart_proxy_url)
                local TOKEN_FILE="$TAVX_DIR/config/cf_token"
                local CF_TOKEN=""; [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ] && CF_TOKEN=$(cat "$TOKEN_FILE")
                if [ -n "$CF_TOKEN" ]; then
                    ui_print info "Token detected, starting fixed tunnel..."
                    start_fixed_tunnel "$PORT" "$PROXY_URL" "$CF_TOKEN"
                else
                    start_temp_tunnel "$PORT" "$PROXY_URL"
                fi
                ui_pause ;;
            
            *"Recommended Settings"*) apply_recommended_settings ;;
            
            *"Remote Link"*)
                local TOKEN_FILE="$TAVX_DIR/config/cf_token"
                if [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then
                    ui_print info "Currently in fixed tunnel mode"
                    echo -e "${GREEN}Please visit the domain you bound in Cloudflare dashboard.${NC}"
                else
                    local LINK=$(wait_for_link_logic)
                    if [ -n "$LINK" ]; then 
                        ui_print success "Current link:"
                        echo -e "\n${YELLOW}$LINK${NC}\n"
                        echo -e "${CYAN}(Long press to copy)${NC}"
                    else 
                        ui_print warn "Cannot get link (service not started or network timeout)"
                    fi
                fi
                ui_pause ;;
                
            *"Logs"*) 
                SUB=$(ui_menu "Select log" "📜 Tavern Log" "🚇 Tunnel Log" "🔙 Back")
                case "$SUB" in *"Tavern"*) safe_log_monitor "$SERVER_LOG" ;; *"Tunnel"*) safe_log_monitor "$CF_LOG" ;; esac ;;
                
            *"Stop"*) stop_services; ui_pause ;;
            *"Back"*) return ;;
        esac
    done
}