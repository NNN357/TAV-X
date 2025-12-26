#!/bin/bash
# TAV-X Core: Update Center

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"
source "$TAVX_DIR/core/install.sh"

check_for_updates() {
    [ ! -d "$TAVX_DIR/.git" ] && return
    (
        cd "$TAVX_DIR" || exit
        if git fetch origin --quiet --timeout=10; then
            LOCAL=$(git rev-parse HEAD)
            REMOTE=$(git rev-parse @{u})
            [ "$LOCAL" != "$REMOTE" ] && echo "true" > "$TAVX_DIR/.update_available" || rm -f "$TAVX_DIR/.update_available"
        fi
    ) >/dev/null 2>&1 &
}

update_sillytavern() {
    ui_header "SillyTavern Smart Update"
    
    if [ ! -d "$INSTALL_DIR/.git" ]; then
        ui_print error "No valid Git repository detected."
        ui_pause; return
    fi

    cd "$INSTALL_DIR" || return
    if ! git symbolic-ref -q HEAD >/dev/null; then
        local current_tag=$(git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)
        ui_print warn "Currently in version-locked state ($current_tag)"
        echo -e "${YELLOW}Please [Unlock] first before updating.${NC}"
        ui_pause; return
    fi

    prepare_network_strategy "SillyTavern/SillyTavern"

    local UPDATE_CMD="source \"$TAVX_DIR/core/utils.sh\"; fix_git_remote \"$INSTALL_DIR\" \"SillyTavern/SillyTavern\"; cd \"$INSTALL_DIR\"; git pull --autostash"
    
    if ui_spinner "Syncing latest code..." "$UPDATE_CMD"; then
        ui_print success "Code sync complete."
        echo ""
        if npm_install_smart "$INSTALL_DIR"; then
            ui_print success "Dependencies updated!"
        else
            ui_print warn "Dependency update encountered issues."
        fi
    else
        ui_print error "Update failed! Possible conflicts or network issues."
    fi
    ui_pause
}

rollback_sillytavern() {
    while true; do
        ui_header "Version Time Machine"
        cd "$INSTALL_DIR" || return
        
        local CURRENT_DESC=""
        local IS_DETACHED=false
        if git symbolic-ref -q HEAD >/dev/null; then
            local branch=$(git rev-parse --abbrev-ref HEAD)
            CURRENT_DESC="${GREEN}Branch: $branch (Latest)${NC}"
        else
            IS_DETACHED=true
            local tag=$(git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)
            CURRENT_DESC="${YELLOW}🔒 Locked: $tag${NC}"
        fi
        
        local TAG_CACHE="$TAVX_DIR/.tag_cache"
        local CACHE_STATUS=""
        if [ -f "$TAG_CACHE" ]; then CACHE_STATUS="(Cached)"; fi
        
        echo -e "Current status: $CURRENT_DESC"
        echo "----------------------------------------"
        
        local MENU_ITEMS=()
        [ "$IS_DETACHED" = true ] && MENU_ITEMS+=("🔓 Unlock (Restore to Latest)")
        MENU_ITEMS+=("⏳ Rollback to Historical Version $CACHE_STATUS")
        MENU_ITEMS+=("🔄 Force Refresh Version List")
        MENU_ITEMS+=("🔀 Switch Channel: Release")
        MENU_ITEMS+=("🔀 Switch Channel: Staging")
        MENU_ITEMS+=("🔙 Back")
        
        CHOICE=$(ui_menu "Select action" "${MENU_ITEMS[@]}")
        
        case "$CHOICE" in
            *"Unlock"*)
                if ui_confirm "Confirm restore to latest Release version?"; then
                    prepare_network_strategy "SillyTavern/SillyTavern"
                    local RESTORE="source \"$TAVX_DIR/core/utils.sh\"; fix_git_remote \"$INSTALL_DIR\" \"SillyTavern/SillyTavern\"; git config remote.origin.fetch \"+refs/heads/*:refs/remotes/origin/*\"; git fetch origin release --depth=1; git reset --hard origin/release; git checkout release"
                    if ui_spinner "Restoring..." "$RESTORE"; then
                        echo ""; npm_install_smart "$INSTALL_DIR"
                        ui_print success "Restored!"
                    else ui_print error "Restore failed"; fi
                fi
                ui_pause ;;
            *"Force Refresh"*)
                rm -f "$TAG_CACHE"
                ui_print info "Cache cleared."
                sleep 0.5 ;;
            *"Rollback to Historical"*)
                prepare_network_strategy "SillyTavern/SillyTavern"
                if [ ! -f "$TAG_CACHE" ]; then
                    local FETCH="source \"$TAVX_DIR/core/utils.sh\"; fix_git_remote \"$INSTALL_DIR\" \"SillyTavern/SillyTavern\"; git fetch --tags"
                    if ! ui_spinner "Fetching from cloud..." "$FETCH"; then
                        ui_print error "Fetch failed"; ui_pause; continue
                    fi
                    git tag --sort=-v:refname | head -n 10 > "$TAG_CACHE"
                fi
                mapfile -t TAG_LIST < "$TAG_CACHE"
                if [ ${#TAG_LIST[@]} -eq 0 ]; then ui_print warn "List is empty"; rm -f "$TAG_CACHE"; ui_pause; continue; fi
                TAG_LIST+=("🔙 Cancel")
                TAG_CHOICE=$(ui_menu "Select version" "${TAG_LIST[@]}")
                if [[ "$TAG_CHOICE" != *"Cancel"* ]]; then
                    echo -e "${RED}Warning: Core files will be reset to resolve conflicts.${NC}"
                    if ui_confirm "Confirm rollback to $TAG_CHOICE?"; then
                        local ROLLBACK_CMD="source \"$TAVX_DIR/core/utils.sh\"; fix_git_remote \"$INSTALL_DIR\" \"SillyTavern/SillyTavern\"; git fetch origin tag \"$TAG_CHOICE\" --depth=1; git reset --hard; git checkout \"$TAG_CHOICE\""
                        if ui_spinner "Time traveling..." "$ROLLBACK_CMD"; then
                            echo ""; npm_install_smart "$INSTALL_DIR"
                            ui_print success "Locked at $TAG_CHOICE"
                        else ui_print error "Switch failed"; fi
                    fi
                fi
                ui_pause ;;
            *"Switch Channel"*)
                local TARGET=""; [[ "$CHOICE" == *"Release"* ]] && TARGET="release"; [[ "$CHOICE" == *"Staging"* ]] && TARGET="staging"
                prepare_network_strategy "SillyTavern/SillyTavern"
                local SW_CMD="source \"$TAVX_DIR/core/utils.sh\"; fix_git_remote \"$INSTALL_DIR\" \"SillyTavern/SillyTavern\"; git config remote.origin.fetch \"+refs/heads/*:refs/remotes/origin/*\"; git fetch origin $TARGET --depth=1; git reset --hard origin/$TARGET; git checkout $TARGET"
                if ui_spinner "Switching to $TARGET..." "$SW_CMD"; then
                    echo ""; npm_install_smart "$INSTALL_DIR"
                    ui_print success "Switch successful!"
                else ui_print error "Switch failed"; fi
                ui_pause ;;
            *"Back"*) return ;;
        esac
    done
}

perform_self_update() {
    prepare_network_strategy "NNN357/TAV-X.git"
    local UPD_CMD="source \"$TAVX_DIR/core/utils.sh\"; fix_git_remote \"$TAVX_DIR\" \"NNN357/TAV-X.git\"; cd \"$TAVX_DIR\"; CURr=\$(git rev-parse --abbrev-ref HEAD); git fetch --all && git reset --hard origin/\$CURr"
    if ui_spinner "Updating script..." "$UPD_CMD"; then
        rm -f "$TAVX_DIR/.update_available"; chmod +x st.sh core/*.sh modules/*.sh scripts/*.js 2>/dev/null
        ui_print success "Done! Restarting..."; sleep 1; exec bash "$TAVX_DIR/st.sh"
    else ui_print error "Failed"; ui_pause; fi
}

update_center_menu() {
    while true; do
        ui_header "Install & Update Center"
        cd "$TAVX_DIR" || return
        TAV_VER_DISP="${CURRENT_VERSION:-Unknown} ($(git rev-parse --short HEAD))"
        ST_VER_DISP="Not Installed"; local st_installed=false
        if [ -d "$INSTALL_DIR/.git" ]; then
            cd "$INSTALL_DIR"
            if ! git symbolic-ref -q HEAD >/dev/null; then
                ST_VER_DISP="${YELLOW}🔒 $(git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD)${NC}"
            else
                ST_VER_DISP="$(git rev-parse --abbrev-ref HEAD) ($(git rev-parse --short HEAD))"
            fi
            st_installed=true
        fi
        
        echo "Script: $TAV_VER_DISP"; echo -e "Tavern: $ST_VER_DISP"; echo "----------------------------------------"
        [ -f "$TAVX_DIR/.update_available" ] && ui_print warn "🔔 New script version available!"
        
        MENU_ITEMS=()
        [ "$st_installed" = true ] && MENU_ITEMS+=("🍷 Update SillyTavern") && MENU_ITEMS+=("🔙 Version Rollback/Switch") || MENU_ITEMS+=("📥 Install SillyTavern")
        MENU_ITEMS+=("📜 Update TAV-X Script")
        MENU_ITEMS+=("🔙 Back to Main Menu")
        
        CHOICE=$(ui_menu "Select action" "${MENU_ITEMS[@]}")
        case "$CHOICE" in
            *"Update SillyTavern"*) update_sillytavern ;;
            *"Install SillyTavern"*) install_sillytavern ;;
            *"Version Rollback"*) rollback_sillytavern ;;
            *"Update TAV-X"*) perform_self_update ;;
            *"Back"*) return ;;
        esac
    done
}