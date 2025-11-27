#!/bin/bash
# TAV-X Module: ADB Keep-Alive System

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 核心函数 ---

check_adb_connection() {
    local device_count=$(adb devices | grep -v "List of devices attached" | grep -c "device")
    if [ "$device_count" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

connect_menu() {
    echo -e "${CYAN}=== 🔌 ADB 连接向导 ===${NC}"
    echo -e "请输入【无线调试】主界面显示的端口号。"
    echo -e "${YELLOW}注意：不是配对端口，是主界面的端口！${NC}"
    echo -e "----------------------------------------"
    
    while true; do
        read -p "请输入端口 (0 返回): " PORT
        if [ "$PORT" == "0" ]; then return; fi
        
        if [[ "$PORT" =~ ^[0-9]+$ ]]; then
            echo -e "${YELLOW}正在连接 127.0.0.1:$PORT ...${NC}"
            OUTPUT=$(adb connect "127.0.0.1:$PORT")
            echo "$OUTPUT"
            
            if [[ "$OUTPUT" == *"connected"* ]] || check_adb_connection; then
                echo -e "${GREEN}✅ 连接成功！${NC}"
                echo "$PORT" > "$HOME/.st_adb_port"
                break
            else
                echo -e "${RED}❌ 连接失败。${NC}"
                echo -e "提示：如果显示 'Connection refused'，请先进行配对(选择菜单3)。"
            fi
        else
            echo -e "${RED}无效端口${NC}"
        fi
    done
    read -p "回车继续..."
}

pair_guide() {
    clear
    echo -e "${CYAN}=== 🤝 配对指引 (Pairing) ===${NC}"
    echo -e "${YELLOW}只有第一次使用，或报错 'Connection refused' 时才需要配对。${NC}"
    echo ""
    echo -e "1. 手机开启分屏，或者快速切换。"
    echo -e "2. 进入开发者选项 -> 无线调试 -> 点击【使用配对码配对设备】。"
    echo -e "3. 记下弹窗里的 IP、端口 和 配对码。"
    echo -e "4. 在下方输入命令进行配对。"
    echo ""
    echo -e "命令格式: ${GREEN}adb pair 127.0.0.1:端口${NC}"
    echo -e "----------------------------------------"
    echo -e "现在，请直接在下方输入配对命令 (输入 0 返回):"
    
    read -p "> " CMD
    if [ "$CMD" == "0" ]; then return; fi
    
    eval "$CMD"
    echo ""
    echo -e "${CYAN}如果显示 Successfully paired，请返回菜单选择 [1] 进行连接。${NC}"
    read -p "回车返回..."
}

run_optimization() {
    if ! check_adb_connection; then
        echo -e "${RED}❌ 未连接 ADB，无法执行。${NC}"; sleep 1; return
    fi

    echo -e "${CYAN}>>> 正在执行保活策略...${NC}"

    echo -e "${YELLOW}[1/4] 💥 解除 32 个子进程限制 (Phantom Process)...${NC}"
    adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
    adb shell "/system/bin/settings put global settings_enable_monitor_phantom_procs false"

    echo -e "${YELLOW}[2/4] 🔋 加入电池优化白名单...${NC}"
    adb shell dumpsys deviceidle whitelist +com.termux

    echo -e "${YELLOW}[3/4] 🛡️ 强制授予后台运行权限...${NC}"
    adb shell cmd appops set com.termux RUN_IN_BACKGROUND allow

    echo -e "${YELLOW}[4/4] 🔥 设置应用活跃级别...${NC}"
    adb shell am set-standby-bucket com.termux active
    
    echo -e "${GREEN}✅ 优化完成！酒馆现在获得了系统级免死金牌。${NC}"
    echo -e "${CYAN}提示：重启手机后【第1项】可能会失效，建议重启后重新运行一次。${NC}"
    read -p "回车返回..."
}

while true; do
    clear
    echo -e "${CYAN}=== 🛡️ ADB 保活系统 (独立模块) ===${NC}"
    
    if check_adb_connection; then
        echo -e "状态: ${GREEN}● 已连接${NC}"
    else
        echo -e "状态: ${RED}● 未连接${NC}"
    fi
    echo "----------------------------------------"
    echo -e "1. 🔗 连接无线 ADB (Connect)"
    echo -e "2. ⚡ 一键执行保活 (Run Optimization)"
    echo -e "3. 🤝 配对模式 (Pairing)"
    echo -e "0. 🔙 返回主程序"
    echo ""
    
    read -p "选择: " choice
    case $choice in
        1) connect_menu ;;
        2) run_optimization ;;
        3) pair_guide ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效输入${NC}"; sleep 0.5 ;;
    esac
done
