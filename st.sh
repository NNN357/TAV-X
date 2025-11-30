#!/bin/bash
# TAV-X Universal Bootstrapper (V3.0 Seamless Migration)

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
CURRENT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

CORE_FILE="$CURRENT_DIR/core/main.sh"
NEW_INSTALL_DIR="$HOME/.tav_x"
NEW_BOOTSTRAP="$NEW_INSTALL_DIR/st.sh"

if [ -f "$CORE_FILE" ]; then
    export TAVX_DIR="$CURRENT_DIR"
    chmod +x "$CORE_FILE"
    exec bash "$CORE_FILE"
    exit 0
fi


echo -e "\033[1;33m"
echo ">>> 检测到旧版结构/核心丢失 (Legacy Environment Detected)..."
echo ">>> 正在迁移至新架构 (Migrating to v2.0)..."
echo -e "\033[0m"

if command -v curl &> /dev/null; then
    bash <(curl -s https://tav-x.future404.qzz.io)
else
    echo "❌ 缺少 curl，无法自动修复。"
    exit 1
fi

if [ -f "$NEW_BOOTSTRAP" ]; then
    echo ""
    echo -e "\033[1;32m>>> 迁移成功！正在启动新版 TAV-X...\033[0m"
    echo -e "\033[1;36m>>> 提示：请重启 Termux 以更新快捷指令。\033[0m"
    sleep 2
    
    exec bash "$NEW_BOOTSTRAP"
else
    echo "❌ 迁移似乎失败，未找到新版启动文件。"
    exit 1
fi
