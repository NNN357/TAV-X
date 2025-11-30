#!/bin/bash
# TAV-X One-Click Installer (V2.0-beta Standard Path)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}>>> 正在初始化安装程序...${NC}"

# 1. 依赖预检
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}>>> 检测到缺少 Git，正在自动安装...${NC}"
    pkg update -y >/dev/null 2>&1
    pkg install git -y
fi

# 2. 定义镜像源
MIRRORS=(
    "https://github.com/"
    "https://mirror.ghproxy.com/https://github.com/"
    "https://ghproxy.net/https://github.com/"
    "https://ghproxy.cc/https://github.com/"
    "https://gh.likk.cc/https://github.com/"
)

TARGET_REPO="Future-404/TAV-X.git"
# 🟢 修改点：路径改为与 st.sh 一致的隐藏目录
INSTALL_DIR="$HOME/.tav_x"
BEST_URL=""
MIN_TIME=9999

echo -e "${YELLOW}>>> 正在进行线路优选 (Speed Test)...${NC}"

for mirror in "${MIRRORS[@]}"; do
    if [ "$mirror" == "https://github.com/" ]; then
        TEST_URL="https://github.com/robots.txt"
    else
        TEST_URL="${mirror}robots.txt"
    fi

    TIME_START=$(date +%s%N)
    if curl -sI -m 2 "$TEST_URL" >/dev/null 2>&1; then
        TIME_END=$(date +%s%N)
        DURATION=$(( (TIME_END - TIME_START) / 1000000 ))
        
        if [ $DURATION -lt 200 ]; then COLOR=$GREEN; 
        elif [ $DURATION -lt 500 ]; then COLOR=$YELLOW; 
        else COLOR=$RED; fi
        
        echo -e "   - 线路检测: ${COLOR}${DURATION}ms${NC} | ${mirror}"
        
        if [ $DURATION -lt $MIN_TIME ]; then
            MIN_TIME=$DURATION
            BEST_URL="${mirror}${TARGET_REPO}"
        fi
    else
        echo -e "   - 线路检测: ${RED}超时${NC} | ${mirror}"
    fi
done

if [ -z "$BEST_URL" ]; then
    echo -e "${RED}⚠️  所有线路检测失败，强制使用官方源...${NC}"
    BEST_URL="https://github.com/Future-404/TAV-X.git"
fi

echo -e "${GREEN}>>> 选中最佳线路: ${BEST_URL}${NC}"

# 3. 清理旧版本
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}>>> 清理旧版本...${NC}"
    rm -rf "$INSTALL_DIR"
fi

# 4. 克隆仓库
echo -e "${GREEN}>>> 开始下载 TAV-X (v2.0-beta)...${NC}"
if git clone --depth 1 -b v2.0-beta "${BEST_URL}" "$INSTALL_DIR"; then
    echo -e "${GREEN}✅ 下载成功${NC}"
else
    echo -e "${RED}❌ 下载失败，请检查网络。${NC}"
    exit 1
fi

# 5. 配置环境
if [ -f "$INSTALL_DIR/st.sh" ]; then
    chmod +x "$INSTALL_DIR/st.sh"
    
    # 智能设置 Alias (指向隐藏目录)
    sed -i '/^alias st=/d' "$HOME/.bashrc"
    echo "alias st='bash $INSTALL_DIR/st.sh'" >> "$HOME/.bashrc"

    export PATH="$INSTALL_DIR:$PATH"

    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}      🎉 TAV-X v2.0 安装成功 (Hidden Mode)     ${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${YELLOW}>>> 请执行以下命令激活:${NC}"
    echo -e "    ${CYAN}source ~/.bashrc${NC}"
    echo -e "    ${CYAN}st${NC}"
    echo ""
else
    echo -e "${RED}❌ 核心文件校验失败${NC}"
    exit 1
fi
