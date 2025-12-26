#!/bin/bash
# [METADATA]
# MODULE_NAME: 🦀 ClewdR Manager
# MODULE_ENTRY: clewd_menu
# [END_METADATA]
source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

CLEWD_DIR="$TAVX_DIR/clewdr"
BIN_FILE="$CLEWD_DIR/clewdr"
LOG_FILE="$CLEWD_DIR/clewdr.log"
SECRETS_FILE="$CLEWD_DIR/secrets.env"

install_clewdr() {
    ui_header "Install ClewdR"

    if ! command -v unzip &> /dev/null; then
        ui_print warn "Installing unzip tool..."
        pkg install unzip -y >/dev/null 2>&1
    fi

    mkdir -p "$CLEWD_DIR"
    cd "$CLEWD_DIR" || return

    local URL="https://github.com/Xerxes-2/clewdr/releases/latest/download/clewdr-android-aarch64.zip"

    prepare_network_strategy "$URL"

    local CMD="
        source \"$TAVX_DIR/core/utils.sh\"
        if download_file_smart '$URL' 'clewd.zip'; then
            unzip -o clewd.zip >/dev/null 2>&1
            chmod +x clewdr
            rm clewd.zip
            exit 0
        else
            exit 1
        fi
    "

    if ui_spinner "Downloading and installing (Smart Acceleration)..." "$CMD"; then
        ui_print success "Installation complete!"
    else
        ui_print error "Download failed, please check network."
    fi
    ui_pause
}

start_clewdr() {
    ui_header "Start ClewdR"
    if [ ! -f "$BIN_FILE" ]; then
        if ui_confirm "Program not detected, install now?"; then
            install_clewdr
            [ ! -f "$BIN_FILE" ] && return
        else return; fi
    fi

    pkill -f "$BIN_FILE"
    cd "$CLEWD_DIR" || return
    if ui_spinner "Starting background service..." "setsid nohup '$BIN_FILE' > '$LOG_FILE' 2>&1 & sleep 3"; then
        if pgrep -f "$BIN_FILE" > /dev/null; then
            local API_PASS=$(grep "API Password:" "$LOG_FILE" | head -n 1 | awk '{print $3}')
            local WEB_PASS=$(grep "Web Admin Password:" "$LOG_FILE" | head -n 1 | awk '{print $4}')
            echo "API_PASS=$API_PASS" > "$SECRETS_FILE"
            echo "WEB_PASS=$WEB_PASS" >> "$SECRETS_FILE"

            ui_print success "Service started!"
            echo ""
            
            if [ "$HAS_GUM" = true ]; then
                echo -e " $(gum style --foreground 212 "📊 Web Admin Panel")"
                echo -e "   URL: $(gum style --foreground 39 "http://127.0.0.1:8484")"
                echo -e "   Password: $(gum style --foreground 220 "${WEB_PASS:-Unknown}")"
                echo ""
                echo -e " $(gum style --foreground 212 "🔌 API Endpoint (SillyTavern)")"
                echo -e "   URL: $(gum style --foreground 39 "http://127.0.0.1:8484/v1")"
                echo -e "   Key: $(gum style --foreground 220 "${API_PASS:-Unknown}")"
            else
                echo "📊 Admin Panel: http://127.0.0.1:8484"
                echo "   Password: ${WEB_PASS:-Unknown}"
                echo ""
                echo "🔌 API URL: http://127.0.0.1:8484/v1"
                echo "   Key: ${API_PASS:-Unknown}"
            fi
        else
            ui_print error "Startup failed, please check logs."
        fi
    else
        ui_print error "Startup timeout."
    fi
    ui_pause
}

stop_clewdr() {
    if pgrep -f "$BIN_FILE" > /dev/null; then
        pkill -f "$BIN_FILE"
        ui_print success "Service stopped."
    else
        ui_print warn "Service not running."
    fi
    sleep 1
}

show_secrets() {
    if [ -f "$SECRETS_FILE" ]; then
        source "$SECRETS_FILE"
        ui_header "Connection Info"
        
        if [ "$HAS_GUM" = true ]; then
            echo -e " $(gum style --foreground 212 "📊 Web Admin")"
            echo -e "   🔗 $(gum style --foreground 39 "http://127.0.0.1:8484")"
            echo -e "   🔑 $(gum style --foreground 220 "${WEB_PASS}")"
            echo ""
            echo -e " $(gum style --foreground 212 "🔌 API Endpoint")"
            echo -e "   🔗 $(gum style --foreground 39 "http://127.0.0.1:8484/v1")"
            echo -e "   🔑 $(gum style --foreground 220 "${API_PASS}")"
        else
            echo "Web Password: ${WEB_PASS}"
            echo "API Key: ${API_PASS}"
        fi
    else
        ui_print error "No cache available, please start service first."
    fi
    ui_pause
}

clewd_menu() {
    while true; do
        ui_header "ClewdR AI Reverse Proxy Manager"

        if pgrep -f "$BIN_FILE" >/dev/null; then
            STATUS="${GREEN}● Running${NC}"
        else
            STATUS="${RED}● Stopped${NC}"
        fi
        echo -e "Status: $STATUS"
        echo ""

        CHOICE=$(ui_menu "Select action" \
            "🚀 Start/Restart Service" \
            "🔑 View Password Info" \
            "📜 View Live Logs" \
            "🛑 Stop Service" \
            "📥 Force Update/Reinstall" \
            "🔙 Back to Main Menu"
        )

        case "$CHOICE" in
            *"Start"*) start_clewdr ;;
            *"Password"*) show_secrets ;;
            *"Logs"*) safe_log_monitor "$LOG_FILE" ;;
            *"Stop"*) stop_clewdr ;;
            *"Update"*) install_clewdr ;;
            *"Back"*) return ;;
        esac
    done
}