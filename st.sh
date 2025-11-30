#!/bin/bash
# TAV-X v2.1 Bootstrapper (Config Safe Fix)

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
export TAVX_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

TARGET_CMD="bash $TAVX_DIR/st.sh"
EXPECTED_ALIAS="alias st='$TARGET_CMD'"

if grep -qF "$EXPECTED_ALIAS" "$HOME/.bashrc"; then
    :
else
    sed -i '/^alias st=/d' "$HOME/.bashrc"
    echo "$EXPECTED_ALIAS" >> "$HOME/.bashrc"
fi

CORE_FILE="$TAVX_DIR/core/main.sh"
if [ -f "$CORE_FILE" ]; then
    chmod +x "$CORE_FILE"
    exec bash "$CORE_FILE"
else
    echo -e "\033[0;31m❌ 致命错误：核心文件丢失 ($CORE_FILE)\033[0m"
    echo "请尝试重新安装或拉取仓库。"
    exit 1
fi
