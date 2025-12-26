#!/bin/bash
# TAV-X Core: Plugin Manager

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

API_URL="https://tav-x-api.future404.qzz.io"
PLUGIN_LIST_FILE="$TAVX_DIR/config/plugins.list"

is_installed() {
    local d=$1
    if [ -d "$INSTALL_DIR/plugins/$d" ] || [ -d "$INSTALL_DIR/public/scripts/extensions/third-party/$d" ]; then return 0; else return 1; fi
}

install_single_plugin() {
    local name=$1; local repo=$2; local s=$3; local c=$4; local dir=$5
    ui_header "Installing Plugin: $name"
    
    if is_installed "$dir"; then
        if ! ui_confirm "Plugin already exists, reinstall?"; then return; fi
    fi

    prepare_network_strategy "$repo"

    local TASKS=""
    if [ "$s" != "-" ]; then
        local b_arg=""; [ "$s" != "HEAD" ] && b_arg="-b $s"
        TASKS+="safe_rm '$INSTALL_DIR/plugins/$dir'; git_clone_smart '$b_arg' '$repo' '$INSTALL_DIR/plugins/$dir' || exit 1;"
    fi
    if [ "$c" != "-" ]; then
        local b_arg=""; [ "$c" != "HEAD" ] && b_arg="-b $c"
        TASKS+="safe_rm '$INSTALL_DIR/public/scripts/extensions/third-party/$dir'; git_clone_smart '$b_arg' '$repo' '$INSTALL_DIR/public/scripts/extensions/third-party/$dir' || exit 1;"
    fi
    
    local WRAP_CMD="source \"$TAVX_DIR/core/utils.sh\"; $TASKS"
    
    if ui_spinner "Downloading plugin (Smart Selection)..." "$WRAP_CMD"; then
        ui_print success "Installation complete!"
    else
        ui_print error "Installation failed, please check network."
    fi
    ui_pause
}

list_install_menu() {
    if [ ! -f "$PLUGIN_LIST_FILE" ]; then ui_print error "Plugin list not found"; ui_pause; return; fi

    while true; do
        ui_header "Plugin Repository"
        MENU_ITEMS=()
        rm -f "$TAVX_DIR/.plugin_map"
        
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            IFS='|' read -r name repo s c dir <<< "$line"
            name=$(echo "$name"|xargs); dir=$(echo "$dir"|xargs)
            
            if is_installed "$dir"; then ICON="✅"; else ICON="📦"; fi
            ITEM="$ICON $name  [$dir]"
            MENU_ITEMS+=("$ITEM")
            echo "$ITEM|$line" >> "$TAVX_DIR/.plugin_map"
        done < "$PLUGIN_LIST_FILE"
        
        MENU_ITEMS+=("🔙 Back")
        CHOICE=$(ui_menu "Search by keyword" "${MENU_ITEMS[@]}")
        if [[ "$CHOICE" == *"Back"* ]]; then return; fi
        
        RAW_LINE=$(grep -F "$CHOICE|" "$TAVX_DIR/.plugin_map" | head -n 1 | cut -d'|' -f2-)
        if [ -n "$RAW_LINE" ]; then
            IFS='|' read -r n r s c d <<< "$RAW_LINE"
            install_single_plugin "$(echo "$n"|xargs)" "$(echo "$r"|xargs)" "$(echo "$s"|xargs)" "$(echo "$c"|xargs)" "$(echo "$d"|xargs)"
        else
            ui_print error "Data parsing error"
            ui_pause
        fi
    done
}

submit_plugin() {
    ui_header "Submit New Plugin"
    echo -e "${YELLOW}Welcome to contribute plugins!${NC}"
    echo -e "${CYAN}Tip: Leave required fields empty or enter '0' to cancel.${NC}"
    echo ""
    local name=$(ui_input "1. Plugin Name (Required)" "" "false")
    if [[ -z "$name" || "$name" == "0" ]]; then ui_print info "Cancelled"; ui_pause; return; fi
    local url=$(ui_input "2. GitHub URL (Required)" "https://github.com/" "false")
    if [[ -z "$url" || "$url" == "0" || "$url" == "https://github.com/" ]]; then ui_print info "Cancelled"; ui_pause; return; fi
    if [[ "$url" != http* ]]; then ui_print error "URL format error"; ui_pause; return; fi
    local dir=$(ui_input "3. Directory Name (Optional, 0 to cancel)" "" "false")
    if [[ "$dir" == "0" ]]; then ui_print info "Cancelled"; ui_pause; return; fi
    
    echo -e "------------------------"
    echo -e "Name: $name"
    echo -e "URL: $url"
    echo -e "Directory: ${dir:-Auto-detect}"
    echo -e "------------------------"
    
    if ! ui_confirm "Confirm submission?"; then ui_print info "Cancelled"; ui_pause; return; fi
    
    local JSON=$(printf '{"name":"%s", "url":"%s", "dirName":"%s"}' "$name" "$url" "$dir")
    
    _auto_heal_network_config
    local network_conf="$TAVX_DIR/config/network.conf"
    local proxy_args=""
    if [ -f "$network_conf" ]; then
        local c=$(cat "$network_conf")
        if [[ "$c" == PROXY* ]]; then
            local val=${c#*|}; val=$(echo "$val"|tr -d '\n\r')
            proxy_args="-x $val"
        fi
    fi
    
    if ui_spinner "Submitting..." "curl -s $proxy_args -X POST -H 'Content-Type: application/json' -d '$JSON' '$API_URL/submit' > $TAVX_DIR/.api_res"; then
        RES=$(cat "$TAVX_DIR/.api_res")
        if echo "$RES" | grep -q "success"; then
            ui_print success "Submission successful! Please wait for review."
        else
            ui_print error "Submission failed: $RES"
        fi
    else
        ui_print error "API connection failed, please check network."
    fi
    ui_pause
}

plugin_menu() {
    while true; do
        ui_header "Plugin Center"
        CHOICE=$(ui_menu "Select option" "📥 Install Plugin" "➕ Submit Plugin" "🔙 Back to Main Menu")
        case "$CHOICE" in
            *"Install"*) list_install_menu ;;
            *"Submit"*) submit_plugin ;;
            *"Back"*) return ;;
        esac
    done
}