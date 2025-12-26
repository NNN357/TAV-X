#!/bin/bash
# TAV-X Core: Security & System Config

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

NETWORK_CONFIG="$TAVX_DIR/config/network.conf"
MEMORY_CONFIG="$TAVX_DIR/config/memory.conf"

configure_server_settings() {
    [ ! -f "$INSTALL_DIR/config.yaml" ] && { ui_print error "Config file not found, please install SillyTavern first."; ui_pause; return; }

    local CONFIG_MAP=(
        "SEPARATOR|--- Basic Connection Settings ---"
        "listen|Allow External Network (0.0.0.0)"
        "whitelistMode|Whitelist Mode (Restrict IP Access)"
        "basicAuthMode|Force Password Login (BasicAuth)"
        "enableUserAccounts|Multi-User Account System"
        "enableDiscreetLogin|Discreet Login (Hide Usernames)"
        
        "SEPARATOR|--- Network & Security Advanced ---"
        "disableCsrfProtection|Disable CSRF Protection (Fix Cross-Origin)"
        "enableCorsProxy|Enable CORS Proxy (Allow External Frontend)"
        "protocol.ipv6|Enable IPv6 Protocol Support"
        "ssl.enabled|Enable SSL/HTTPS"
        "hostWhitelist.enabled|Host Header Whitelist Check"

        "SEPARATOR|--- Performance & Updates ---"
        "performance.lazyLoadCharacters|Lazy Load Characters (Faster Startup)"
        "performance.useDiskCache|Enable Disk Cache"
        "extensions.enabled|Load Extensions"
        "extensions.autoUpdate|Auto-Update Extensions (Recommend Off)"
        "enableServerPlugins|Load Server Plugins"
        "enableServerPluginsAutoUpdate|Auto-Update Server Plugins"

        "SEPARATOR|--- Danger Zone ---"
        "RESET_CONFIG|⚠️ Reset to Default (Delete Config File)"
    )

    while true; do
        ui_header "Core Settings"
        echo -e "${CYAN}Click item to toggle status${NC}"
        echo "----------------------------------------"

        local MENU_OPTS=()
        local KEY_LIST=()
        
        for item in "${CONFIG_MAP[@]}"; do
            local key="${item%%|*}"
            local label="${item#*|}"
            if [ "$key" == "SEPARATOR" ]; then
                MENU_OPTS+=("📂 $label")
                KEY_LIST+=("SEPARATOR")
                continue
            fi
            if [ "$key" == "RESET_CONFIG" ]; then
                MENU_OPTS+=("💥 $label")
                KEY_LIST+=("RESET_CONFIG")
                continue
            fi
            
            local val=$(config_get "$key")
            local icon="🔴"
            local stat="[Off]"
            
            if [ "$val" == "true" ]; then
                icon="🟢"
                stat="[On]"
            fi
            
            if [[ "$key" == "whitelistMode" || "$key" == "performance.useDiskCache" ]]; then
                if [ "$val" == "true" ]; then icon="🟡"; fi
            fi
            
            if [[ "$key" == *"autoUpdate"* || "$key" == *"AutoUpdate"* ]]; then
                 if [ "$val" == "true" ]; then icon="🟡"; fi
            fi

            MENU_OPTS+=("$icon $label $stat")
            KEY_LIST+=("$key")
        done
        
        MENU_OPTS+=("🔙 Back")

        local CHOICE_IDX
        if [ "$HAS_GUM" = true ]; then
            local SELECTED_TEXT=$(gum choose "${MENU_OPTS[@]}" --header "" --cursor.foreground 212)
            for i in "${!MENU_OPTS[@]}"; do
                if [[ "${MENU_OPTS[$i]}" == "$SELECTED_TEXT" ]]; then CHOICE_IDX=$i; break; fi
            done
        else
            local i=1
            for opt in "${MENU_OPTS[@]}"; do echo "$i. $opt"; ((i++)); done
            read -p "Enter number: " input_idx
            if [[ "$input_idx" =~ ^[0-9]+$ ]]; then
                CHOICE_IDX=$((input_idx - 1))
            fi
        fi

        if [[ "${MENU_OPTS[$CHOICE_IDX]}" == *"Back"* ]]; then
            return
        fi

        if [ -n "$CHOICE_IDX" ] && [ "$CHOICE_IDX" -ge 0 ] && [ "$CHOICE_IDX" -lt "${#KEY_LIST[@]}" ]; then
            local target_key="${KEY_LIST[$CHOICE_IDX]}"
            if [ "$target_key" == "SEPARATOR" ]; then continue; fi
            if [ "$target_key" == "RESET_CONFIG" ]; then
                echo ""
                echo -e "${RED}Warning: This will permanently delete the current config.yaml file!${NC}"
                echo -e "All custom settings will be lost, SillyTavern will generate new defaults on next start."
                echo ""
                if ui_confirm "Are you sure you want to factory reset?"; then
                    rm -f "$INSTALL_DIR/config.yaml"
                    ui_print success "Config file deleted."
                    echo -e "${YELLOW}Please go to [🚀 Start Services] -> [Local Mode] to generate new config.${NC}"
                    ui_pause
                    return
                fi
                continue
            fi

            local current_val=$(config_get "$target_key")
            local new_val="true"
            
            if [ "$current_val" == "true" ]; then new_val="false"; fi
            
            if config_set "$target_key" "$new_val"; then
                sleep 0.1
            fi
        fi
    done
}

configure_memory() {
    ui_header "Memory Configuration (Memory Tuning)"
    
    local mem_info=$(free -m | grep "Mem:")
    local total_mem=$(echo "$mem_info" | awk '{print $2}')
    local avail_mem=$(echo "$mem_info" | awk '{print $7}')
    
    [[ -z "$total_mem" ]] && total_mem=0
    [[ -z "$avail_mem" ]] && avail_mem=0
    
    local safe_max=$((total_mem - 2048))
    if [ "$safe_max" -lt 1024 ]; then safe_max=1024; fi
    
    local curr_set="Default (Node.js Auto)"
    if [ -f "$MEMORY_CONFIG" ]; then
        curr_set="$(cat "$MEMORY_CONFIG") MB"
    fi

    echo -e "${CYAN}Current Device Memory Status:${NC}"
    echo -e "📦 Total Physical Memory: ${GREEN}${total_mem} MB${NC}"
    echo -e "🟢 Currently Available: ${YELLOW}${avail_mem} MB${NC} (Free)"
    echo -e "⚙️ Current Setting: ${PURPLE}${curr_set}${NC}"
    echo "----------------------------------------"
    echo -e "${YELLOW}Recommended Settings:${NC}"
    echo -e "• 4096 (4GB) - Balanced, suitable for most cases"
    echo -e "• $safe_max (Max) - Theoretical limit, higher may cause background kill"
    echo "----------------------------------------"
    
    echo -e "Enter max memory to allocate for SillyTavern (MB)"
    echo -e "Enter ${RED}0${NC} to restore default, enter specific number to customize."
    
    local input_mem=$(ui_input "Enter (e.g. 4096)" "" "false")
    
    if [[ ! "$input_mem" =~ ^[0-9]+$ ]]; then
        ui_print error "Please enter a valid number."
        ui_pause; return
    fi
    
    if [ "$input_mem" -eq 0 ]; then
        rm -f "$MEMORY_CONFIG"
        ui_print success "Restored to default memory policy."
    else
        if [ "$input_mem" -gt "$safe_max" ]; then
            ui_print warn "Note: Setting ($input_mem) is near or exceeds physical limit ($total_mem)!"
            if ! ui_confirm "This may cause Termux to crash, are you sure?"; then
                ui_pause; return
            fi
        elif [ "$input_mem" -gt "$avail_mem" ]; then
            ui_print warn "Tip: Setting is greater than available memory, system may use Swap."
        fi
        echo "$input_mem" > "$MEMORY_CONFIG"
        ui_print success "Max memory set to: ${input_mem} MB"
    fi
    ui_pause
}

configure_download_network() {
    ui_header "Download Network Settings"
    local curr_mode="Auto (Smart Self-Healing)"
    if [ -f "$NETWORK_CONFIG" ]; then
        local c=$(cat "$NETWORK_CONFIG"); curr_mode="${c#*|}"
        [ ${#curr_mode} -gt 30 ] && curr_mode="${curr_mode:0:28}..."
    fi
    echo -e "Current Strategy: ${CYAN}$curr_mode${NC}\n"
    echo -e "Note: Script will auto-detect proxy or use mirrors by default, no manual setup needed."
    echo -e "Only use custom settings if you have non-standard ports or need to force specific options."
    echo ""

    CHOICE=$(ui_menu "Select mode" "🔧 Configure Custom Proxy" "🔄 Reset to Auto Mode" "🔙 Back")

    case "$CHOICE" in
        *"Custom"*)
            local url=$(ui_input "Enter proxy (e.g. http://127.0.0.1:7890)" "" "false")
            if [[ "$url" =~ ^(http|https|socks5|socks5h)://.* ]]; then 
                echo "PROXY|$url" > "$NETWORK_CONFIG"
                ui_print success "Custom proxy saved."
            else 
                ui_print error "Format error, please include protocol (e.g. socks5://)"
            fi
            ui_pause ;;
        *"Reset"*)
            if [ -f "$NETWORK_CONFIG" ]; then
                rm -f "$NETWORK_CONFIG"
                ui_print success "Reset complete. Script will auto-manage network connection."
            else
                ui_print info "Already in default auto mode."
            fi
            ui_pause ;;
    esac
}

change_port() {
    ui_header "Change Port"
    
    CURR=$(config_get port)
    
    if [[ -z "$CURR" ]] || [[ "$CURR" == "-1" ]]; then
        ui_print error "Config file error: Cannot get valid port number ($CURR)."
        ui_print warn "Please check if config.yaml format is correct."
        ui_pause
        return
    fi
    
    local new=$(ui_input "Enter new port (1024-65535)" "$CURR" "false")
    
    if [[ "$new" =~ ^[0-9]+$ ]] && [ "$new" -ge 1024 ] && [ "$new" -le 65535 ]; then
        config_set port "$new"
        ui_print success "Port changed to $new"
    else 
        ui_print error "Invalid port"
    fi
    ui_pause
}

reset_password() {
    ui_header "Reset Password"
    [ ! -d "$INSTALL_DIR" ] && { ui_print error "SillyTavern not installed"; ui_pause; return; }
    
    cd "$INSTALL_DIR" || return
    config_set enableUserAccounts true
    
    [ ! -f "recover.js" ] && { ui_print error "recover.js missing"; ui_pause; return; }
    echo -e "${YELLOW}User list:${NC}"; ls -F data/ | grep "/" | grep -v "^_" | sed 's/\///g' | sed 's/^/  - /'
    local u=$(ui_input "Username" "default-user" "false"); local p=$(ui_input "New password" "" "false")
    [ -z "$p" ] && ui_print warn "Password is empty" || { echo ""; node recover.js "$u" "$p"; echo ""; ui_print success "Password reset"; }
    ui_pause
}

configure_api_proxy() {
    while true; do
        ui_header "API Proxy Settings"
        local is_enabled=$(config_get requestProxy.enabled)
        local current_url=$(config_get requestProxy.url)
        [ -z "$current_url" ] && current_url="Not Set"

        echo -e "Current Configuration:"
        if [ "$is_enabled" == "true" ]; then
            echo -e "  🟢 Status: ${GREEN}Enabled${NC}"
            echo -e "  🔗 URL: ${CYAN}$current_url${NC}"
        else
            echo -e "  🔴 Status: ${RED}Disabled${NC}"
            echo -e "  🔗 URL: ${CYAN}$current_url${NC} (Inactive)"
        fi
        echo "----------------------------------------"

        CHOICE=$(ui_menu "Select action" "🔄 Sync System Proxy" "✏️ Manual Input" "🚫 Disable Proxy" "🔙 Back")
        
        case "$CHOICE" in
            *"Sync"*)
                if [ -f "$NETWORK_CONFIG" ]; then
                    c=$(cat "$NETWORK_CONFIG")
                    if [[ "$c" == PROXY* ]]; then 
                        v=${c#*|}; v=$(echo "$v"|tr -d '\n\r'); 
                        config_set requestProxy.enabled true 
                        config_set requestProxy.url "$v" 
                        ui_print success "Sync successful: $v"
                    else 
                        ui_print warn "System not in proxy mode"
                    fi
                else 
                    local dyn=$(get_active_proxy)
                    if [ -n "$dyn" ]; then
                        config_set requestProxy.enabled true 
                        config_set requestProxy.url "$dyn" 
                        ui_print success "Auto-detected and applied: $dyn"
                    else
                        ui_print warn "No local proxy detected"
                    fi
                fi 
                ui_pause ;;
            *"Manual"*)
                i=$(ui_input "Proxy URL" "" "false")
                if [[ "$i" =~ ^http.* ]]; then 
                    config_set requestProxy.enabled true 
                    config_set requestProxy.url "$i" 
                    ui_print success "Saved and enabled"
                else 
                    ui_print error "Format error"
                fi 
                ui_pause ;;
            *"Disable"*) 
                config_set requestProxy.enabled false 
                ui_print success "Proxy connection disabled";
                ui_pause ;;
            *"Back"*) return ;;
        esac
    done
}

configure_cf_token() {
    ui_header "Cloudflare Tunnel Token"
    local token_file="$TAVX_DIR/config/cf_token"
    
    local current_stat="${YELLOW}Not Configured (Using Temp Tunnel)${NC}"
    if [ -f "$token_file" ] && [ -s "$token_file" ]; then
        local t=$(cat "$token_file")
        current_stat="${GREEN}Configured${NC} (${t:0:6}......)"
    fi

    echo -e "Current Status: $current_stat"
    echo "----------------------------------------"
    echo -e "Note: Using Token allows custom domain binding, more stable connection."
    echo -e "Get your Tunnel Token from Cloudflare Zero Trust dashboard."
    echo ""

    CHOICE=$(ui_menu "Select action" "✏️ Enter/Update Token" "🗑️ Clear Token (Restore Default)" "🔙 Back")

    case "$CHOICE" in
        *"Enter"*)
            local input=$(ui_input "Paste Token here" "" "false")
            if [ -n "$input" ]; then
                echo "$input" > "$token_file"
                ui_print success "Token saved!"
            fi
            ui_pause ;;
        *"Clear"*)
            rm -f "$token_file"
            ui_print success "Token cleared, restored to temporary tunnel mode."
            ui_pause ;;
        *"Back"*) return ;;
    esac
}

security_menu() {
    while true; do
        ui_header "System Settings"
        CHOICE=$(ui_menu "Select function" \
            "⚙️  Core Settings" \
            "🧠 Memory Configuration" \
            "📥 Download Network Settings" \
            "🌐 API Proxy Settings" \
            "☁️  Cloudflare Token" \
            "🔐 Reset Login Password" \
            "🔌 Change Server Port" \
            "🧨 Uninstall & Reset" \
            "🔙 Back to Main Menu"
        )
        case "$CHOICE" in
            *"Core Settings"*) configure_server_settings ;;
            *"Memory"*) configure_memory ;; 
            *"Download"*) configure_download_network ;;
            *"API"*) configure_api_proxy ;;
            *"Cloudflare"*) configure_cf_token ;;
            *"Password"*) reset_password ;;
            *"Port"*) change_port ;;
            *"Uninstall"*) uninstall_menu ;;
            *"Back"*) return ;;
        esac
    done
}