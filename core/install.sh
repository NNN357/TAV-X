#!/bin/bash
# TAV-X Core: Installer Logic

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/utils.sh"

install_sillytavern() {
    header "酒馆安装向导"

    # 1. 检查是否已安装
    if [ -d "$INSTALL_DIR" ]; then
        warn "检测到已安装目录: $INSTALL_DIR"
        read -p "是否覆盖安装？(y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            info "已取消安装。"
            pause
            return
        fi
        # 简单备份
        mv "$INSTALL_DIR" "${INSTALL_DIR}_bak_$(date +%s)"
        success "旧版本已备份。"
    fi

    # 2. 线路选择
    echo -e "正在拉取代码..."
    local MIRROR="https://gh-proxy.com/"
    git clone --depth 1 "${MIRROR}https://github.com/SillyTavern/SillyTavern.git" "$INSTALL_DIR"

    if [ ! -d "$INSTALL_DIR" ]; then
        error "下载失败，请检查网络。"
        return
    fi

    # 3. 安装依赖
    cd "$INSTALL_DIR" || return
    info "正在安装 Node.js 依赖 (这可能需要几分钟)..."
    
    # 设置淘宝源加速
    npm config set registry https://registry.npmmirror.com
    
    if npm install --no-audit --fund --loglevel error; then
        success "依赖安装完成。"
    else
        error "依赖安装失败。"
        return
    fi

    # 4. 配置优化 (Write config.yaml)
    info "正在应用最佳配置..."
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
    success "配置已写入。"
    
    echo ""
    success "🎉 安装流程全部结束！"
    pause
}
