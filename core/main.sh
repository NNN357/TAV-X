#!/bin/bash
# TAV-X Core: Main Logic

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"
source "$TAVX_DIR/core/deps.sh"
source "$TAVX_DIR/core/security.sh"
source "$TAVX_DIR/core/plugins.sh"
source "$TAVX_DIR/core/backup.sh"
source "$TAVX_DIR/core/updater.sh"
source "$TAVX_DIR/core/install.sh"
source "$TAVX_DIR/core/launcher.sh"
source "$TAVX_DIR/core/uninstall.sh"
source "$TAVX_DIR/core/about.sh"

check_dependencies
check_for_updates
send_analytics

# --- Dynamic Module Loader ---
load_advanced_tools_menu() {
    local module_files=()
    local module_names=()
    local module_entries=()
    local menu_options=()

    # 1. Scan all .sh files in modules directory
    # Use nullglob to prevent errors when directory is empty
    shopt -s nullglob
    for file in "$TAVX_DIR/modules/"*.sh; do
        # Check if file contains metadata marker
        if grep -q "\[METADATA\]" "$file"; then
            # Extract MODULE_NAME and MODULE_ENTRY
            local m_name=$(grep "MODULE_NAME:" "$file" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            local m_entry=$(grep "MODULE_ENTRY:" "$file" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # Only add to menu if both name and entry exist
            if [ -n "$m_name" ] && [ -n "$m_entry" ]; then
                module_files+=("$file")
                module_names+=("$m_name")
                module_entries+=("$m_entry")
                menu_options+=("$m_name")
            fi
        fi
    done
    shopt -u nullglob

    # If no modules found
    if [ ${#menu_options[@]} -eq 0 ]; then
        ui_print warn "No valid tool modules detected."
        echo -e "${YELLOW}Please check if scripts in modules/ contain [METADATA] header.${NC}"
        ui_pause
        return
    fi

    menu_options+=("🔙 Back")

    # 2. Display dynamic menu
    # Loop until user selects back
    while true; do
        local choice=$(ui_menu "Advanced Toolbox (Plugins)" "${menu_options[@]}")

        if [[ "$choice" == *"Back"* ]]; then
            return
        fi

        # 3. Match and execute
        local matched=false
        for i in "${!module_names[@]}"; do
            if [[ "${module_names[$i]}" == "$choice" ]]; then
                local target_file="${module_files[$i]}"
                local target_entry="${module_entries[$i]}"
                
                # Load script environment
                source "$target_file"
                
                # Check if entry function exists
                if command -v "$target_entry" &> /dev/null; then
                    $target_entry
                else
                    ui_print error "Module error: Entry function '$target_entry' not found"
                    ui_pause
                fi
                matched=true
                break
            fi
        done
        
        # Shouldn't reach here, but defensive coding
        if [ "$matched" = false ]; then
            ui_print error "Cannot load module, please try again."
            ui_pause
        fi
    done
}

while true; do
    S_ST=0; S_CF=0; S_ADB=0; S_CLEWD=0; S_GEMINI=0; S_AUDIO=0
    pgrep -f "node server.js" >/dev/null && S_ST=1
    pgrep -f "cloudflared" >/dev/null && S_CF=1
    command -v adb &>/dev/null && adb devices 2>/dev/null | grep -q "device$" && S_ADB=1
    pgrep -f "clewd" >/dev/null && S_CLEWD=1
    pgrep -f "run.py" >/dev/null && S_GEMINI=1
    if [ -f "$TAVX_DIR/.audio_heartbeat.pid" ] && kill -0 $(cat "$TAVX_DIR/.audio_heartbeat.pid") 2>/dev/null; then
        S_AUDIO=1
    fi

    NET_DL="Auto-Select"
    if [ -f "$NETWORK_CONFIG" ]; then
        CONF=$(cat "$NETWORK_CONFIG"); TYPE=${CONF%%|*}; VAL=${CONF#*|}
        [ ${#VAL} -gt 25 ] && VAL="...${VAL: -22}"
        [ "$TYPE" == "PROXY" ] && NET_DL="Local Proxy ($VAL)"
        [ "$TYPE" == "MIRROR" ] && NET_DL="Mirror ($VAL)"
    fi

    NET_API="Direct (System)"
    if [ -f "$CONFIG_FILE" ]; then
        if grep -A 4 "requestProxy:" "$CONFIG_FILE" | grep -q "enabled: true"; then
            URL=$(grep -A 4 "requestProxy:" "$CONFIG_FILE" | grep "url:" | awk '{print $2}' | tr -d '"')
            [ -z "$URL" ] && URL="Enabled"
            NET_API="Proxy ($URL)"
        fi
    fi

    ui_header ""
    ui_dashboard "$S_ST" "$S_CF" "$S_ADB" "$NET_DL" "$NET_API" "$S_CLEWD" "$S_GEMINI" "$S_AUDIO"

    OPT_UPD="🔄 Install & Update"
    [ -f "$TAVX_DIR/.update_available" ] && OPT_UPD="🔄 Install & Update 🔔"

    CHOICE=$(ui_menu "Main Menu" \
        "🚀 Start Services" \
        "$OPT_UPD" \
        "⚙️  System Settings" \
        "🧩 Plugin Manager" \
        "🌐 Network Settings" \
        "💾 Backup & Restore" \
        "🛠️  Advanced Tools" \
        "💡 Help & Support" \
        "🚪 Exit"
    )

    case "$CHOICE" in
        *"Start Services"*)
            if [ ! -d "$INSTALL_DIR" ]; then ui_print warn "Please install SillyTavern first!"; ui_pause; else start_menu; fi ;;
        *"Install & Update"*) update_center_menu ;;
        *"System Settings") security_menu ;;
        *"Plugin Manager") plugin_menu ;;
        *"Network Settings") configure_download_network ;;
        *"Backup & Restore") backup_menu ;;
        
        # --- Changed: unified dynamic loader call ---
        *"Advanced Tools") load_advanced_tools_menu ;;
        
        *"Help & Support"*) show_about_page ;;
            
        *"Exit"*) 
            EXIT_OPT=$(ui_menu "Select exit method" \
                "🏃 Keep running in background" \
                "🛑 Stop all services and exit" \
                "🔙 Cancel" \
            )
            
            case "$EXIT_OPT" in
                *"Keep running"*)
                    ui_print info "Program minimized, services continue running in background."
                    ui_print info "Type 'st' next time to bring back the menu."
                    exit 0 
                    ;;
                *"Stop all"*)
                    echo ""
                    if ui_confirm "Are you sure you want to stop all services (Tavern, Tunnel, Keep-alive, etc.)?"; then
                        ui_spinner "Stopping all processes..." "
                            if [ -f '$TAVX_DIR/.audio_heartbeat.pid' ]; then
                                HB_PID=\$(cat '$TAVX_DIR/.audio_heartbeat.pid')
                                kill -9 \$HB_PID >/dev/null 2>&1
                                rm -f '$TAVX_DIR/.audio_heartbeat.pid'
                            fi
                            pkill -f 'mpv --no-terminal'
                            adb kill-server >/dev/null 2>&1
                            pkill -f 'adb'
                            pkill -f 'node server.js'
                            pkill -f 'cloudflared'
                            pkill -f 'clewd'
                            pkill -f 'run.py'
                            
                            termux-wake-unlock 2>/dev/null
                            rm -f '$TAVX_DIR/.temp_link'
                        "
                        ui_print success "All services stopped, resources released."
                        exit 0
                    else
                        ui_print info "Operation cancelled."
                    fi
                    ;;
                *) ;;
            esac
            ;;
            
        *) exit 0 ;;
    esac
done