#!/bin/bash
# TAV-X Core: Unified Update Center (UI v4.3 JSON Fix)

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

perform_self_update() {
    ui_header "TAV-X 自我更新"
    fix_git_remote "$TAVX_DIR" "Future-404/TAV-X.git"
    cd "$TAVX_DIR" || return
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    CMD="git fetch --all && git reset --hard origin/$CURRENT_BRANCH"
    if ui_spinner "正在拉取脚本更新..." "$CMD"; then
        ui_print success "✅ 更新成功！重启中..."
        rm -f "$TAVX_DIR/.update_available"
        chmod +x st.sh core/*.sh modules/*.sh scripts/*.js 2>/dev/null
        sleep 1; exec bash "$TAVX_DIR/st.sh"
    else
        ui_print error "更新失败。"; ui_pause
    fi
}

update_center_menu() {
    while true; do
        ui_header "安装与更新管理"
        
        cd "$TAVX_DIR" || return
        TAV_HASH=$(git rev-parse --short HEAD)
        TAV_VER_DISP="${CURRENT_VERSION:-Unknown} ($TAV_HASH)"
        
        ST_VER_DISP="未安装"
        local st_installed=false
        
        if [ -d "$INSTALL_DIR/.git" ]; then
            cd "$INSTALL_DIR"
            ST_HASH=$(git rev-parse --short HEAD)
            
            if [ -f "package.json" ]; then
            
                ST_REAL_VER=$(grep '"version":' package.json | awk -F'"' '{print $4}')
            fi
            
            if [ -n "$ST_REAL_VER" ]; then
                ST_VER_DISP="v$ST_REAL_VER ($ST_HASH)"
            else
                ST_BRANCH=$(git rev-parse --abbrev-ref HEAD)
                ST_VER_DISP="$ST_BRANCH ($ST_HASH)"
            fi
            st_installed=true
        fi
        
        if [ "$HAS_GUM" = true ]; then
            local lbl_script=$(gum style --foreground 240 "脚本版本:")
            local val_script=$(gum style --foreground 39 "$TAV_VER_DISP")
            local lbl_st=$(gum style --foreground 240 "酒馆版本:")
            local val_st
            if [ "$st_installed" = true ]; then val_st=$(gum style --foreground 82 "$ST_VER_DISP"); else val_st=$(gum style --foreground 220 "$ST_VER_DISP"); fi
            
            gum style --border normal --border-foreground 240 --padding "0 1" "$lbl_script $val_script" "$lbl_st     $val_st"
        else
            echo "脚本: $TAV_VER_DISP"
            echo "酒馆: $ST_VER_DISP"
            echo "----------------------------------------"
        fi
        
        if [ -f "$TAVX_DIR/.update_available" ]; then ui_print warn "🔔 脚本有新版本可用！"; fi
        
        MENU_ITEMS=()
        if [ "$st_installed" = true ]; then
            MENU_ITEMS+=("🍷 更新 SillyTavern")
            MENU_ITEMS+=("🔙 版本回退/切换")
        else
            MENU_ITEMS+=("📥 安装 SillyTavern")
        fi
        MENU_ITEMS+=("📜 更新 TAV-X 脚本")
        MENU_ITEMS+=("🔙 返回主菜单")
        
        CHOICE=$(ui_menu "请选择操作" "${MENU_ITEMS[@]}")
        case "$CHOICE" in
            *"更新 SillyTavern"*) update_sillytavern ;;
            *"安装 SillyTavern"*) install_sillytavern ;;
            *"版本回退"*) rollback_sillytavern ;;
            *"更新 TAV-X"*) perform_self_update ;;
            *"返回"*) return ;;
        esac
    done
}
