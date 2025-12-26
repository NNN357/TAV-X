#!/bin/bash

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

verify_kill_switch() {
    local TARGET_PHRASE="I understand the risks and have made a backup"
    
    ui_header "⚠️ High-Risk Operation Confirmation"
    echo -e "${RED}Warning: This operation is irreversible! Data will be permanently lost!${NC}"
    echo -e "To confirm this is you, please type the following phrase exactly:"
    echo ""
    if [ "$HAS_GUM" = true ]; then
        gum style --border double --border-foreground 196 --padding "0 1" --foreground 220 "$TARGET_PHRASE"
    else
        echo ">>> $TARGET_PHRASE"
    fi
    echo ""
    
    local input=$(ui_input "Type confirmation phrase here" "" "false")
    
    if [ "$input" == "$TARGET_PHRASE" ]; then
        return 0
    else
        ui_print error "Verification failed! Text doesn't match, operation cancelled."
        ui_pause
        return 1
    fi
}

uninstall_st() {
    if ! verify_kill_switch; then return; fi
    
    if ui_spinner "Deleting SillyTavern data..." "source \"$TAVX_DIR/core/utils.sh\"; safe_rm '$INSTALL_DIR'"; then
        ui_print success "SillyTavern uninstalled."
    else
        ui_print error "Deletion failed, please check permissions."
    fi
    ui_pause
}

uninstall_clewd() {
    local CLEWD_DIR="$TAVX_DIR/clewdr"
    if ! verify_kill_switch; then return; fi
    
    pkill -f "clewdr"
    
    if ui_spinner "Removing ClewdR..." "source \"$TAVX_DIR/core/utils.sh\"; safe_rm '$CLEWD_DIR'"; then
        ui_print success "ClewdR module uninstalled."
    else
        ui_print error "Deletion failed."
    fi
    ui_pause
}

uninstall_gemini() {
    local GEMINI_DIR="$TAVX_DIR/gemini_proxy"
    ui_header "Uninstall Gemini Proxy"
    
    if [ ! -d "$GEMINI_DIR" ]; then
        ui_print warn "Gemini module not detected."
        ui_pause; return
    fi

    if ! verify_kill_switch; then return; fi
    
    pkill -f "run.py"
    
    if ui_spinner "Removing Gemini module..." "source \"$TAVX_DIR/core/utils.sh\"; safe_rm '$GEMINI_DIR'"; then
        ui_print success "Gemini proxy and credentials uninstalled."
    else
        ui_print error "Deletion failed."
    fi
    ui_pause
}

uninstall_adb() {
    local ADB_DIR="$TAVX_DIR/adb_tools"
    ui_header "Uninstall ADB Components"
    
    if [ ! -d "$ADB_DIR" ] && ! command -v adb &> /dev/null; then
        ui_print warn "ADB components not detected."
        ui_pause; return
    fi

    echo -e "This will clean up TAV-X managed ADB files and config."
    if ! ui_confirm "Confirm continue?"; then return; fi

    if [ -d "$ADB_DIR" ]; then
        ui_spinner "Deleting local files..." "source \"$TAVX_DIR/core/utils.sh\"; safe_rm '$ADB_DIR'"
        sed -i '/adb_tools\/platform-tools/d' "$HOME/.bashrc"
        ui_print success "Local components and environment variables cleaned."
    fi

    if command -v adb &> /dev/null; then
        echo ""
        echo -e "${YELLOW}System android-tools (pkg) detected.${NC}"
        if ui_confirm "Also uninstall Google ADB?"; then
            if ui_spinner "Uninstalling system package..." "pkg uninstall android-tools -y"; then
                ui_print success "Google ADB uninstalled."
            else
                ui_print error "Uninstall failed."
            fi
        else
            ui_print info "System ADB kept."
        fi
    fi
    
    ui_pause
}

uninstall_deps() {
    ui_header "Uninstall Dependencies"
    echo -e "${RED}Warning: This will uninstall Node.js, Cloudflared and other components.${NC}"
    echo -e "If other software in your Termux depends on them, it may cause crashes."
    echo ""
    
    if ! verify_kill_switch; then return; fi
    
    local PKGS="nodejs nodejs-lts cloudflared git android-tools"
    
    if ui_spinner "Uninstalling system packages..." "pkg uninstall $PKGS -y"; then
        ui_print success "Dependencies cleaned."
        echo "Note: Gum (UI component) is kept to maintain script functionality."
    else
        ui_print error "Errors occurred during uninstall."
    fi
    ui_pause
}

full_wipe() {
    ui_header "Complete Uninstall (Factory Reset)"
    echo -e "${RED}Danger Level: ⭐⭐⭐⭐⭐${NC}"
    echo -e "This will perform all of the following:"
    echo -e "  1. Delete all SillyTavern data"
    echo -e "  2. Delete ClewdR, Gemini, ADB and other modules"
    echo -e "  3. Delete TAV-X script and config"
    echo -e "  4. Clean environment variables (.bashrc)"
    echo ""
    
    if ! verify_kill_switch; then return; fi
    
    pkill -f "node server.js"
    pkill -f "cloudflared"
    pkill -f "clewdr"
    pkill -f "run.py"
    
    ui_spinner "Performing cleanup..." "
        source \"$TAVX_DIR/core/utils.sh\"
        safe_rm '$INSTALL_DIR'
        safe_rm '$TAVX_DIR/clewdr'
        safe_rm '$TAVX_DIR/gemini_proxy'
        safe_rm '$TAVX_DIR/adb_tools'
        sed -i '/alias st=/d' '$HOME/.bashrc'
        sed -i '/adb_tools\/platform-tools/d' '$HOME/.bashrc'
    "
    
    ui_print success "Business data cleared."
    echo ""
    echo -e "${YELLOW}Final step: Self-destruct initiated...${NC}"
    echo -e "Thank you for using TAV-X, goodbye! 👋"
    sleep 2
    safe_rm "$TAVX_DIR"
    
    exit 0
}

uninstall_menu() {
    while true; do
        ui_header "Uninstall & Reset Center"
        echo -e "${RED}⚠️  Please proceed with caution, data is priceless!${NC}"
        echo ""
        
        CHOICE=$(ui_menu "Select action" \
            "🗑️ Uninstall SillyTavern" \
            "🦀 Uninstall ClewdR Module" \
            "♊ Uninstall Gemini Module" \
            "🤖 Uninstall ADB Components" \
            "📦 Uninstall Dependencies" \
            "💥 Complete Wipe (Full Reset)" \
            "🔙 Back"
        )
        
        case "$CHOICE" in
            *"SillyTavern"*) uninstall_st ;;
            *"ClewdR"*) uninstall_clewd ;;
            *"Gemini"*) uninstall_gemini ;;
            *"ADB"*) uninstall_adb ;;
            *"Dependencies"*) uninstall_deps ;;
            *"Complete Wipe"*) full_wipe ;;
            *"Back"*) return ;;
        esac
    done
}