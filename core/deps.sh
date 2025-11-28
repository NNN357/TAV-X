#!/bin/bash
# TAV-X Core: Dependency Manager

check_dependencies() {
    # 如果已检查过，跳过 (简单的缓存机制)
    if [ "$DEPS_CHECKED" == "true" ]; then return 0; fi

    local MISSING_PKGS=""
    
    # 快速静默检测
    if command -v node &> /dev/null && \
       command -v git &> /dev/null && \
       command -v cloudflared &> /dev/null; then
        export DEPS_CHECKED="true"
        return 0
    fi

    header "环境初始化"
    info "正在检查核心组件..."

    if ! command -v node &> /dev/null; then 
        warn "未找到 Node.js"
        MISSING_PKGS="$MISSING_PKGS nodejs-lts"
    fi

    if ! command -v git &> /dev/null; then 
        warn "未找到 Git"
        MISSING_PKGS="$MISSING_PKGS git"
    fi
    
    if ! command -v cloudflared &> /dev/null; then 
        warn "未找到 Cloudflared"
        MISSING_PKGS="$MISSING_PKGS cloudflared"
    fi

    # 补充基础工具
    if ! command -v tar &> /dev/null; then MISSING_PKGS="$MISSING_PKGS tar"; fi

    if [ -n "$MISSING_PKGS" ]; then
        info "检测到缺失组件，正在自动补全: $MISSING_PKGS"
        pkg update -y
        pkg install $MISSING_PKGS -y
        
        # 二次确认
        if command -v node &> /dev/null; then
            success "环境修复完成！"
            export DEPS_CHECKED="true"
            pause
        else
            error "环境安装失败，请检查网络或更换 Termux 源。"
            exit 1
        fi
    else
        success "环境完整。"
        export DEPS_CHECKED="true"
    fi
}
