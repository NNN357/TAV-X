#!/bin/bash
# TAV-X Core: Installer & Version Controller (UI v4.0)

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"
JS_TOOL="$TAVX_DIR/scripts/config_mgr.js"

export -f git_clone_smart
export -f info success error warn

apply_git_proxy() {
    if [ -f "$NETWORK_CONFIG" ]; then
        local conf=$(cat "$NETWORK_CONFIG")
        if [[ "$conf" == PROXY* ]]; then
            local val=${conf#*|}; val=$(echo "$val" | tr -d '\n\r')
            git config http.proxy "$val"; git config https.proxy "$val"
        else
            git config --unset http.proxy; git config --unset https.proxy
        fi
    fi
}

install_sillytavern() {
    ui_header "酒馆安装向导"
    if [ -d "$INSTALL_DIR" ]; then
        if ui_confirm "目录已存在，是否覆盖/重装？"; then
            mv "$INSTALL_DIR" "${INSTALL_DIR}_bak_$(date +%s)"
            ui_print success "旧版已备份。"
        else return; fi
    fi

    local CMD_CLONE="source $TAVX_DIR/core/utils.sh; git_clone_smart '' 'https://github.com/SillyTavern/SillyTavern.git' '$INSTALL_DIR'"
    
    if ui_spinner "正在拉取代码 (自动优选线路)..." "$CMD_CLONE"; then
        ui_print success "代码下载完成。"
    else
        ui_print error "下载失败，请检查网络。"
        ui_pause; return
    fi

    cd "$INSTALL_DIR" || return
    
    local CMD_NPM="npm config set registry https://registry.npmmirror.com && npm install --no-audit --fund --loglevel error"
    if ui_spinner "正在安装 Node.js 依赖..." "$CMD_NPM"; then
        ui_print success "依赖安装完成。"
    else
        ui_print error "依赖安装失败。"
        ui_pause; return
    fi


    mkdir -p "$INSTALL_DIR"
    cat > "$INSTALL_DIR/config.yaml" << YAML
whitelistMode: false
enableUserAccounts: true
enableServerPlugins: true
enableDiscreetLogin: true
useDiskCache: false
lazyLoadCharacters: true
requestProxy:
  enabled: false
  url: ""
YAML
    ui_print success "默认配置已写入。"
    ui_print success "🎉 安装流程结束！"
    ui_pause
}

update_sillytavern() {
    ui_header "更新 SillyTavern"
    if [ ! -d "$INSTALL_DIR/.git" ]; then ui_print error "未找到酒馆目录！"; ui_pause; return; fi
    
    fix_git_remote "$INSTALL_DIR" "SillyTavern/SillyTavern.git"
    cd "$INSTALL_DIR" || return
    
    git stash >/dev/null 2>&1
    
    local CMD_UPD="git pull && npm install --no-audit --fund --loglevel error"
    
    if ui_spinner "正在拉取更新并刷新依赖..." "$CMD_UPD"; then
        ui_print success "✅ 更新完成！"
    else
        ui_print error "更新失败 (网络超时或冲突)。"
    fi
    
    git config --unset http.proxy
    git config --unset https.proxy
    ui_pause
}

rollback_sillytavern() {
    ui_header "版本回退时光机"
    if [ ! -d "$INSTALL_DIR/.git" ]; then ui_print error "未找到酒馆仓库！"; ui_pause; return; fi
    
    fix_git_remote "$INSTALL_DIR" "SillyTavern/SillyTavern.git"
    cd "$INSTALL_DIR" || return
    
    if ! ui_spinner "正在获取版本列表..." "git fetch --tags"; then
        ui_print error "无法获取版本信息。"
        ui_pause; return
    fi
    
    mapfile -t tags < <(git tag --sort=-creatordate | grep -v "staging" | head -n 15)
    if [ ${#tags[@]} -eq 0 ]; then ui_print error "未找到版本标签。"; ui_pause; return; fi

    MENU_ITEMS=("🔄 恢复到最新版 (release)")
    for tag in "${tags[@]}"; do MENU_ITEMS+=("🕰️ $tag"); done
    MENU_ITEMS+=("🔙 返回")

    CHOICE=$(ui_menu "请选择目标版本" "${MENU_ITEMS[@]}")
    
    if [[ "$CHOICE" == *"返回"* ]]; then return; fi
    
    if [[ "$CHOICE" == *"最新版"* ]]; then
        local CMD="git checkout release && git pull && npm install --no-audit --fund --loglevel error"
        if ui_spinner "正在恢复最新版..." "$CMD"; then
            ui_print success "✅ 已恢复！"
        else ui_print error "操作失败。"; fi
    else
    
        TARGET_TAG=$(echo "$CHOICE" | awk '{print $2}')
        local CMD="git checkout $TARGET_TAG && rm -rf node_modules package-lock.json && npm install --no-audit --fund --loglevel error"
        
        if ui_spinner "正在穿越到 $TARGET_TAG ..." "$CMD"; then
            ui_print success "✅ 穿越成功: $TARGET_TAG"
        else ui_print error "穿越失败。"; fi
    fi
    ui_pause
}
