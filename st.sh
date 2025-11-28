#!/bin/bash
# TAV-X v2.0 Bootstrapper (Self-Healing)

# 1. 定位真实路径
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
export TAVX_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

# 2. Alias 自愈逻辑
CURRENT_ALIAS=$(grep "alias st=" "$HOME/.bashrc" 2>/dev/null)
EXPECTED_ALIAS="alias st='bash $TAVX_DIR/st.sh'"
if [[ "$CURRENT_ALIAS" != *"$TAVX_DIR/st.sh"* ]]; then
    # 静默更新 Alias
    sed -i '/alias st=/d' "$HOME/.bashrc"
    echo "$EXPECTED_ALIAS" >> "$HOME/.bashrc"
fi

# 3. 启动 Core
CORE_FILE="$TAVX_DIR/core/main.sh"
if [ -f "$CORE_FILE" ]; then
    chmod +x "$CORE_FILE"
    exec bash "$CORE_FILE"
else
    echo "❌ Core missing: $CORE_FILE"
    exit 1
fi
