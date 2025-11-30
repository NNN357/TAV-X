#!/bin/bash
# TAV-X v2.0.0 Bootstrapper (Migration & Self-Healing)

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
CURRENT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

INSTALL_DIR="$HOME/.tav_x"

CORE_FILE="$INSTALL_DIR/core/main.sh"

if [ ! -f "$CORE_FILE" ]; then
    echo -e "\033[1;36m>>> TAV-X v2.0 架构升级中...\033[0m"
    
    if ! command -v git &> /dev/null; then
        echo "正在安装 Git..."
        pkg update -y && pkg install git -y
    fi

    if [ -d "$INSTALL_DIR" ]; then 
        echo -e "\033[1;33m清理旧目录结构...\033[0m"
        rm -rf "$INSTALL_DIR"
    fi

    echo -e "\033[1;32m正在拉取核心组件...\033[0m"
    git clone --depth 1 https://ghproxy.net/https://github.com/Future-404/TAV-X.git "$INSTALL_DIR"

    if [ ! -f "$CORE_FILE" ]; then
        echo -e "\033[0;31m❌ 迁移失败：无法连接 GitHub。请检查网络。\033[0m"
        exit 1
    fi
    
    echo -e "\033[1;32m✅ 迁移完成！\033[0m"
    
    chmod +x "$INSTALL_DIR/st.sh" "$INSTALL_DIR/core/"*.sh "$INSTALL_DIR/modules/"*.sh
fi

TARGET_CMD="bash $INSTALL_DIR/st.sh"
EXPECTED_ALIAS="alias st='$TARGET_CMD'"

if ! grep -qF "$INSTALL_DIR/st.sh" "$HOME/.bashrc"; then
    sed -i '/alias st=/d' "$HOME/.bashrc"
    echo "$EXPECTED_ALIAS" >> "$HOME/.bashrc"
    echo -e "\033[1;33m提示: 快捷指令已更新。下次启动只需输入 'st'\033[0m"
fi

export TAVX_DIR="$INSTALL_DIR"
exec bash "$CORE_FILE"