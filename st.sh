#!/bin/bash
# TAV-X Universal Bootstrapper (V2.0 Final Hybrid)
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
CURRENT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

CORE_FILE="$CURRENT_DIR/core/main.sh"

if [ -f "$CORE_FILE" ]; then
    export TAVX_DIR="$CURRENT_DIR"
    chmod +x "$CORE_FILE"
    exec bash "$CORE_FILE"
    
else
    
    echo -e "\033[1;33m" # Yellow
    echo ">>> 检测到 TAV-X 核心文件缺失 (或正在从旧版本升级)..."
    echo ">>> Detect missing core files (or upgrading from legacy version)..."
    echo -e "\033[0m"
    
    echo -e "\033[1;32m>>> 正在启动自动修复/迁移程序...\033[0m"
    echo -e "\033[1;32m>>> Starting auto-repair/migration sequence...\033[0m"
    echo ""
    
    if command -v curl &> /dev/null; then
        bash <(curl -s https://tav-x.future404.qzz.io)
    else
        echo -e "\033[0;31m❌ 错误: 未找到 curl 工具，无法自动修复。\033[0m"
        echo "请手动执行: pkg install curl git -y"
        exit 1
    fi
    
    exit 0
fi