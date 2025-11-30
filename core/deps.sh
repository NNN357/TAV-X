#!/bin/bash
# TAV-X Core: Dependency Manager (V2.3 Strict Check)

check_dependencies() {
    if [ "$DEPS_CHECKED" == "true" ]; then return 0; fi

    local MISSING_PKGS=""
    
    if command -v node &> /dev/null && \
       command -v git &> /dev/null && \
       command -v cloudflared &> /dev/null && \
       command -v gum &> /dev/null && \
       command -v tar &> /dev/null; then
        export DEPS_CHECKED="true"
        return 0
    fi

    header "环境初始化"
    info "正在检查全套组件..."

    if ! command -v node &> /dev/null; then 
        warn "未找到 Node.js (核心引擎)"
        MISSING_PKGS="$MISSING_PKGS nodejs-lts"
    fi

    if ! command -v git &> /dev/null; then 
        warn "未找到 Git (版本控制)"
        MISSING_PKGS="$MISSING_PKGS git"
    fi
    
    if ! command -v cloudflared &> /dev/null; then 
        warn "未找到 Cloudflared (内网穿透)"
        MISSING_PKGS="$MISSING_PKGS cloudflared"
    fi

    if ! command -v gum &> /dev/null; then
        warn "未找到 Gum (UI 界面)"
        MISSING_PKGS="$MISSING_PKGS gum"
    fi

    if ! command -v tar &> /dev/null; then
        warn "未找到 Tar (备份工具)"
        MISSING_PKGS="$MISSING_PKGS tar"
    fi

    if [ -n "$MISSING_PKGS" ]; then
        info "检测到缺失组件，正在自动补全: $MISSING_PKGS"
        
        pkg update -y
        pkg install $MISSING_PKGS -y
        
        if command -v node &> /dev/null && \
           command -v git &> /dev/null && \
           command -v cloudflared &> /dev/null && \
           command -v gum &> /dev/null && \
           command -v tar &> /dev/null; then
            
            success "环境全量修复完成！"
            export DEPS_CHECKED="true"
            pause
        else
        
            error "环境修复不完整！部分组件安装失败。"
            echo -e "${YELLOW}请尝试切换网络或手动运行: pkg install $MISSING_PKGS${NC}"
            exit 1
        fi
    else
        success "环境完整。"
        export DEPS_CHECKED="true"
    fi
}
