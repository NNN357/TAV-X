#!/bin/bash
# TAV-X v2.0 Bootstrapper (The Key)

# 1. 智能定位真实路径
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
export TAVX_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

# 2. 核心文件校验
CORE_FILE="$TAVX_DIR/core/main.sh"

if [ -f "$CORE_FILE" ]; then
    # 赋予执行权限
    chmod +x "$CORE_FILE" "$TAVX_DIR"/core/*.sh "$TAVX_DIR"/modules/*.sh 2>/dev/null
    # 启动主程序
    exec bash "$CORE_FILE"
else
    echo -e "\033[0;31m❌ 致命错误：核心文件丢失 ($CORE_FILE)\033[0m"
    echo "请尝试重新运行安装命令修复。"
    exit 1
fi
