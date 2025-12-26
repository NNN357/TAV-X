#!/bin/bash
# TAV-X Core: Installer

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

install_sillytavern() {
    ui_header "SillyTavern Installation Wizard"

    if [ -d "$INSTALL_DIR" ]; then
        ui_print warn "Old version directory detected: $INSTALL_DIR"
        echo -e "${RED}Continuing will clear the old directory!${NC}"
        if ! ui_confirm "Confirm overwrite installation?"; then return; fi
        safe_rm "$INSTALL_DIR"
    fi

    prepare_network_strategy "SillyTavern/SillyTavern"

    local CLONE_CMD="source \"$TAVX_DIR/core/utils.sh\"; git_clone_smart '-b release' 'SillyTavern/SillyTavern' '$INSTALL_DIR'"
    
    if ui_spinner "Fetching SillyTavern source (Release)..." "$CLONE_CMD"; then
        ui_print success "Source download complete!"
    else
        ui_print error "Source download failed, please check network connection."
        ui_pause; return 1
    fi

    echo ""
    ui_print info "Preparing to install dependencies..."
    
    if npm_install_smart "$INSTALL_DIR"; then
        echo ""
        ui_print success "Dependencies installed!"
        chmod +x "$INSTALL_DIR/start.sh" 2>/dev/null
        
        if ui_confirm "Apply recommended settings (auto-optimize)?"; then
             source "$TAVX_DIR/core/launcher.sh"
             apply_recommended_settings
        fi

        ui_print success "🎉 SillyTavern installed successfully!"
        echo -e "You can now use [🚀 Start Services] from main menu to run it."
    else
        echo ""
        ui_print error "Dependency installation failed."
        echo -e "${YELLOW}Tip: You can retry later in [Install & Update] -> [Version Switch/Repair].${NC}"
    fi
    ui_pause
}