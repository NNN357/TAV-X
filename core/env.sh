#!/bin/bash
# TAV-X Core: Environment Context

# --- 全局常量 ---
export TAVX_ROOT="$HOME/.tav_x"
export INSTALL_DIR="$HOME/SillyTavern"
export CONFIG_FILE="$INSTALL_DIR/config.yaml"
export CURRENT_VERSION="v2.0.0-alpha"

# --- 颜色定义 ---
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[1;34m'
export CYAN='\033[1;36m'
export NC='\033[0m'

# --- 核心函数: 打印 LOG ---
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[DONE]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- 核心函数: 上下文导出 (供子模块使用) ---
# 将当前环境导出到临时文件，供 modules 独立脚本 source
export_env_context() {
    cat > /tmp/tavx_env.sh << EOL
export TAVX_ROOT="$TAVX_ROOT"
export INSTALL_DIR="$INSTALL_DIR"
# 颜色定义
export RED='$RED'
export GREEN='$GREEN'
export YELLOW='$YELLOW'
export NC='$NC'
EOL
}
