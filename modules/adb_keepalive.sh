#!/bin/bash
# TAV-X Module: ADB Keep-Alive (UI v4.0 Final)

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

PKG="com.termux"
LOG_FILE="$TAVX_DIR/adb_log.txt"

check_dependency() {
    if ! command -v adb &> /dev/null; then
        ui_print warn "正在安装 android-tools..."
        pkg install android-tools termux-tools -y >/dev/null 2>&1
    fi
}

check_adb_status() {
    if adb devices 2>/dev/null | grep -q "device$"; then return 0; else return 1; fi
}

# --- 核心功能 ---
pair_device() {
    ui_header "ADB 无线配对向导"
    echo -e "${YELLOW}请前往开发者选项 -> 无线调试 -> 使用配对码配对设备${NC}"
    adb start-server >/dev/null 2>&1
    
    local host=$(ui_input "输入 IP:端口 (如 127.0.0.1:12345)" "127.0.0.1:" "false")
    local code=$(ui_input "输入 6 位配对码" "" "false")
    [[ -z "$code" ]] && return
    
    if ui_spinner "正在配对..." "adb pair '$host' '$code' > '$LOG_FILE' 2>&1"; then
        if grep -q "Successfully paired" "$LOG_FILE"; then
            ui_print success "配对成功！"
        else
            ui_print error "配对失败 (请检查配对码)。"
        fi
    else
        ui_print error "连接超时。"
    fi
    ui_pause
}

connect_adb() {
    ui_header "连接 ADB 服务"
    if check_adb_status; then ui_print success "ADB 已连接。"; ui_pause; return; fi
    
    echo -e "${YELLOW}请查看无线调试界面的【IP地址和端口】${NC}"
    local port=$(ui_input "请输入连接端口 (仅数字)" "" "false")
    [[ ! "$port" =~ ^[0-9]+$ ]] && { ui_print error "格式错误"; ui_pause; return; }
    
    if ui_spinner "正在连接 127.0.0.1:$port ..." "adb connect 127.0.0.1:$port"; then
        sleep 1
        if check_adb_status; then ui_print success "连接成功！"; else ui_print error "连接失败。"; fi
    fi
    ui_pause
}

apply_keepalive() {
    ui_header "执行系统级保活"
    if ! check_adb_status; then ui_print error "ADB 未连接。"; ui_pause; return; fi
    
    if ui_confirm "禁用幽灵进程杀手 (Phantom Process Killer)?"; then
        adb shell device_config put activity_manager max_phantom_processes 2147483647
        adb shell settings put global settings_enable_monitor_phantom_procs false
        ui_print success "已执行。"
    fi
    
    if ui_confirm "加入电池优化白名单?"; then
        adb shell dumpsys deviceidle whitelist +$PKG
        ui_print success "已执行。"
    fi
    
    if ui_confirm "允许后台运行权限 (AppOps)?"; then
        adb shell cmd appops set $PKG RUN_IN_BACKGROUND allow
        adb shell cmd appops set $PKG RUN_ANY_IN_BACKGROUND allow
        adb shell cmd appops set $PKG START_FOREGROUND allow
        ui_print success "已执行。"
    fi
    
    ui_print info "申请 CPU 唤醒锁..."
    termux-wake-lock
    ui_pause
}

# --- 新增：撤销权限 ---
revoke_permissions() {
    ui_header "释放资源与权限"
    if ! check_adb_status; then ui_print error "ADB 未连接。"; ui_pause; return; fi
    
    echo -e "${RED}即将撤销 Termux 的后台运行特权。${NC}"
    if ui_confirm "确定要撤销所有保活策略吗？"; then
        ui_spinner "正在重置系统参数..." "
            adb shell device_config delete activity_manager max_phantom_processes
            adb shell settings delete global settings_enable_monitor_phantom_procs
            adb shell dumpsys deviceidle whitelist -$PKG
            adb shell cmd appops set $PKG RUN_IN_BACKGROUND default
            adb shell cmd appops set $PKG RUN_ANY_IN_BACKGROUND default
            adb shell cmd appops set $PKG START_FOREGROUND default
        "
        termux-wake-unlock
        ui_print success "所有特权已撤销，唤醒锁已释放。"
    else
        ui_print info "已取消。"
    fi
    ui_pause
}

# --- 菜单循环 (修正版) ---
# 注意：这里我们不写 while true，而是定义成函数供 main.sh 调用
# 如果直接运行此脚本，则在底部调用函数

adb_menu_loop() {
    check_dependency
    while true; do
        ui_header "ADB 保活工具"
        if check_adb_status; then
            echo -e "状态: ${GREEN}● 已连接${NC}"
        else
            echo -e "状态: ${RED}● 未连接${NC}"
        fi
        echo ""
        
        CHOICE=$(ui_menu "请选择操作" \
            "🔗 连接 ADB (Connect)" \
            "🤝 无线配对 (Pairing)" \
            "🛡️ 执行保活 (Apply Fix)" \
            "🧹 释放所有权限 (Revoke All)" \
            "🔙 返回上级"
        )
        
        case "$CHOICE" in
            *"连接"*) connect_adb ;;
            *"配对"*) pair_device ;;
            *"保活"*) apply_keepalive ;;
            *"释放"*) revoke_permissions ;;
            *"返回"*) return ;; # 关键：使用 return 而不是 exit
        esac
    done
}

# 如果是被 source 调用的，不自动执行；如果是直接执行的，则运行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    adb_menu_loop
fi
