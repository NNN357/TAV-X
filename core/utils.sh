#!/bin/bash
# TAV-X Core: Utilities & UI Helpers

# --- Banner 显示 ---
print_banner() {
    clear
    echo -e "${PURPLE}"
    cat << "BANNER"
   d8P
d888888P  Termux Audio Visual eXperience
  ?88'    [ v2.0.0-Alpha | Architecture Refactored ]
  88P   
  88b   
  `?8b  
BANNER
    echo -e "${BLUE}────────────────────────────────────────────────────${NC}"
}

pause() {
    echo ""
    read -n 1 -s -r -p "按任意键继续..."
    echo ""
}

retry_cmd() {
    local max_attempts=3
    local attempt=1
    local cmd="$@"
    while [ $attempt -le $max_attempts ]; do
        if eval "$cmd"; then return 0; fi
        warn "操作失败，正在重试 ($attempt/$max_attempts)..."
        sleep 2
        ((attempt++))
    done
    error "超过最大重试次数: $cmd"
    return 1
}

# --- 标题栏 ---
header() {
    clear
    print_banner
    echo -e "${CYAN}>>> $1 ${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────${NC}"
}
