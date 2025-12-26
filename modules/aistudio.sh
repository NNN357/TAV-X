#!/bin/bash
# [METADATA]
# MODULE_NAME: 🏗️  AIStudio Proxy
# MODULE_ENTRY: aistudio_menu
# [END_METADATA]
source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

REPO_URL="https://github.com/starowo/AIStudioBuildProxy"
PLUGIN_NAME="AIStudioBuildProxy"
SERVER_BRANCH="server"
CLIENT_BRANCH="client"

PATH_SERVER="$INSTALL_DIR/plugins/$PLUGIN_NAME"
PATH_CLIENT="$INSTALL_DIR/public/scripts/extensions/third-party/$PLUGIN_NAME"

check_st_installed() {
    if [ ! -d "$INSTALL_DIR" ]; then
        ui_print error "SillyTavern installation directory not detected."
        ui_print info "Please install SillyTavern in main menu first."
        return 1
    fi
    return 0
}

enable_server_plugins_conf() {
    ui_print info "Checking configuration..."
    if config_set "enableServerPlugins" "true"; then
        ui_print success "Server plugins support enabled (enableServerPlugins)"
    else
        ui_print warn "Config modification failed, please check config.yaml manually later"
    fi
}

install_aistudio() {
    check_st_installed || { ui_pause; return; }
    ui_header "Deploy AIStudioBuildProxy"

    enable_server_plugins_conf

    prepare_network_strategy "$REPO_URL"

    ui_print info "Processing server component..."
    safe_rm "$PATH_SERVER"
    local CMD_SERVER="source \"$TAVX_DIR/core/utils.sh\"; git_clone_smart '-b $SERVER_BRANCH' '$REPO_URL' '$PATH_SERVER'"
    
    if ui_spinner "Downloading server code..." "$CMD_SERVER"; then
        ui_print success "Server code ready."
        
        if [ -f "$PATH_SERVER/package.json" ]; then
            ui_print info "Installing dependencies (npm install)..."
            if npm_install_smart "$PATH_SERVER"; then
                ui_print success "Dependencies installed."
            else
                ui_print error "Dependency installation failed."
                ui_pause; return
            fi
        fi
    else
        ui_print error "Server download failed."
        ui_pause; return
    fi

    echo ""

    ui_print info "Processing client component..."
    safe_rm "$PATH_CLIENT"
    mkdir -p "$(dirname "$PATH_CLIENT")"
    
    local CMD_CLIENT="source \"$TAVX_DIR/core/utils.sh\"; git_clone_smart '-b $CLIENT_BRANCH' '$REPO_URL' '$PATH_CLIENT'"
    
    if ui_spinner "Downloading client extension..." "$CMD_CLIENT"; then
        ui_print success "Client extension ready."
        echo ""
        ui_print success "🎉 AIStudioBuildProxy installation complete!"
        echo -e "${YELLOW}Please restart SillyTavern to load the new plugin.${NC}"
        echo -e "Service ports: HTTP 8889 / WS 9998"
    else
        ui_print error "Client download failed."
    fi
    ui_pause
}

uninstall_aistudio() {
    ui_header "Uninstall AIStudioBuildProxy"
    
    if [ ! -d "$PATH_SERVER" ] && [ ! -d "$PATH_CLIENT" ]; then
        ui_print warn "No installed components detected."
        ui_pause; return
    fi

    if ! ui_confirm "Are you sure you want to delete this plugin?"; then return; fi

    ui_spinner "Cleaning files..." "
        rm -rf '$PATH_SERVER'
        rm -rf '$PATH_CLIENT'
    "
    ui_print success "Uninstalled. Restart tavern to take effect."
    ui_pause
}

check_status() {
    local s_ver="Not Installed"
    local c_ver="Not Installed"
    
    if [ -d "$PATH_SERVER" ]; then s_ver="${GREEN}Installed${NC}"; fi
    if [ -d "$PATH_CLIENT" ]; then c_ver="${GREEN}Installed${NC}"; fi
    
    local port_stat="${RED}Not Running${NC}"
    if timeout 0.1 bash -c "</dev/tcp/127.0.0.1/8889" 2>/dev/null; then
        port_stat="${GREEN}Running (Port 8889)${NC}"
    fi

    echo -e "Server Status: $s_ver"
    echo -e "Client Status: $c_ver"
    echo -e "Run Status:    $port_stat"
    echo "----------------------------------------"
}

aistudio_menu() {
    while true; do
        ui_header "AIStudio Proxy Service"
        check_status

        CHOICE=$(ui_menu "Select action" \
            "📥 Install/Update Plugin (Recommended)" \
            "🗑️ Uninstall Plugin" \
            "🔙 Back"
        )

        case "$CHOICE" in
            *"Install"*) install_aistudio ;;
            *"Uninstall"*) uninstall_aistudio ;;
            *"Back"*) return ;;
        esac
    done
}