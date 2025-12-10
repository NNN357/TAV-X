#!/bin/bash
# TAV-X Module: ADB Keep-Alive

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

PKG="com.termux"
LOG_FILE="$TAVX_DIR/adb_log.txt"
LEGACY_ADB_DIR="$TAVX_DIR/adb_tools"
HEARTBEAT_PID="$TAVX_DIR/.audio_heartbeat.pid"
SILENCE_FILE="$TAVX_DIR/config/silence.wav"
check_dependency() {
    if command -v adb &> /dev/null; then
        if adb --version &> /dev/null; then
            return 0
        fi
        ui_print warn "ADB 架构错误，尝试自动修复..."
    fi

    ui_header "ADB 组件安装"
    if [ -d "$LEGACY_ADB_DIR" ]; then rm -rf "$LEGACY_ADB_DIR"; sed -i '/adb_tools\/platform-tools/d' "$HOME/.bashrc"; fi

    ui_print info "正在安装 android-tools..."
    if ui_spinner "安装中..." "pkg update -y >/dev/null 2>&1; pkg install android-tools -y"; then
        if command -v adb &> /dev/null; then ui_print success "ADB 安装成功！"; else ui_print error "安装失败，请重启 Termux 重试。"; fi
    else
        ui_print error "安装过程出错。";
    fi
    ui_pause
}

check_adb_status() {
    if ! command -v adb &> /dev/null; then echo "${RED}未安装${NC}"; return; fi
    if adb devices 2>/dev/null | grep -q "device$"; then return 0; else return 1; fi
}

check_audio_deps() {
    local MISSING=""
    if ! command -v mpv &> /dev/null; then MISSING="$MISSING mpv"; fi
    if ! command -v sox &> /dev/null; then MISSING="$MISSING sox"; fi
    
    if [ -n "$MISSING" ]; then
        ui_header "安装音频组件"
        ui_print info "正在安装防杀依赖: $MISSING"
        pkg install $MISSING -y
    fi
}

generate_silence() {
    mkdir -p "$(dirname "$SILENCE_FILE")"
    if [ ! -f "$SILENCE_FILE" ]; then
        ui_print info "生成静音音频样本..."
        sox -n -r 44100 -c 2 "$SILENCE_FILE" trim 0.0 10.0
    fi
}

start_heartbeat() {
    check_audio_deps
    generate_silence
    
    if [ -f "$HEARTBEAT_PID" ]; then
        local old_pid=$(cat "$HEARTBEAT_PID")
        if kill -0 "$old_pid" 2>/dev/null; then
            ui_print warn "音频心跳已在运行中。"
            return
        fi
    fi

    ui_header "启动音频心跳"
    echo -e "${YELLOW}策略：模拟前台媒体播放，强制提升进程优先级。${NC}"
    echo ""
    nohup bash -c "while true; do \
        mpv --no-terminal --volume=0 --loop=inf \"$SILENCE_FILE\"; \
        sleep 1; \
    done" > /dev/null 2>&1 &
    
    echo $! > "$HEARTBEAT_PID"
    termux-wake-lock
    
    ui_print success "心跳已启动！(PID: $(cat "$HEARTBEAT_PID"))"
    ui_pause
}

stop_heartbeat() {
    if [ -f "$HEARTBEAT_PID" ]; then
        local pid=$(cat "$HEARTBEAT_PID")
        kill -9 "$pid" 2>/dev/null
        rm -f "$HEARTBEAT_PID"
        pkill -f "mpv --no-terminal"
        termux-wake-unlock
        ui_print success "音频心跳已停止。"
    else
        ui_print warn "心跳未运行。"
    fi
    ui_pause
}
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
            echo -e "${YELLOW}日志:${NC}"; cat "$LOG_FILE"
        fi
    else
        ui_print error "连接超时。";
    fi
    ui_pause
}

connect_adb() {
    ui_header "连接 ADB 服务"
    if check_adb_status; then ui_print success "ADB 已连接。"; ui_pause; return; fi
    
    echo -e "${YELLOW}请查看无线调试界面的【IP地址和端口】${NC}"
    local target=$(ui_input "输入 IP:端口" "127.0.0.1:" "false")
    
    if [ -z "$target" ] || [ "$target" == "127.0.0.1:" ]; then
        ui_print warn "地址为空，已取消。"
        return
    fi
    
    if ui_spinner "正在连接 $target ..." "adb connect $target"; then
        sleep 1
        if check_adb_status; then ui_print success "连接成功！"; else ui_print error "连接失败。"; fi
    fi
    ui_pause
}

apply_keepalive() {
    ui_header "执行系统级保活"
    if ! check_adb_status; then ui_print error "ADB 未连接。"; ui_pause; return; fi
    
    if ui_confirm "1. 禁用幽灵进程杀手 (Android 12+)?"; then
        adb shell device_config put activity_manager max_phantom_processes 2147483647
        adb shell settings put global settings_enable_monitor_phantom_procs false
        ui_print success "已执行。"
    fi
    
    if ui_confirm "2. 加入电池优化白名单?"; then
        adb shell dumpsys deviceidle whitelist +$PKG
        ui_print success "已执行。"
    fi
    
    if ui_confirm "3. 允许后台运行权限 (AppOps)?"; then
        adb shell cmd appops set $PKG RUN_IN_BACKGROUND allow
        adb shell cmd appops set $PKG RUN_ANY_IN_BACKGROUND allow
        adb shell cmd appops set $PKG START_FOREGROUND allow
        ui_print success "已执行。"
    fi
    ui_print info "申请 CPU 唤醒锁..."
    if [ "$OS_TYPE" == "TERMUX" ]; then termux-wake-lock; fi
    
    ui_pause
}

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

adb_menu_loop() {
    if [ "$OS_TYPE" == "LINUX" ]; then
        ui_print warn "Linux 服务器不需要保活模块。"
        ui_pause; return
    fi

    check_dependency
    while true; do
        ui_header "ADB 保活工具"
        
        local s_adb="${RED}● 未连接${NC}"; check_adb_status && s_adb="${GREEN}● 已连接${NC}"
        local s_audio="${RED}● 关闭${NC}"
        if [ -f "$HEARTBEAT_PID" ] && kill -0 $(cat "$HEARTBEAT_PID") 2>/dev/null; then 
            s_audio="${GREEN}● 运行中 (Loop)${NC}"
        fi
        
        echo -e "ADB状态: $s_adb | 音频心跳: $s_audio"
        echo "----------------------------------------"
        
        CHOICE=$(ui_menu "请选择操作" \
            "🤝 无线配对" \
            "🔗 连接 ADB" \
            "🛡️ 执行系统级保活" \
            "🎵 启动音频心跳" \
            "🔇 停止音频心跳" \
            "🧹 释放所有权限" \
            "🔙 返回上级"
        )
        
        case "$CHOICE" in
            *"无线配对"*) pair_device ;;
            *"连接 ADB"*) connect_adb ;;
            *"系统级保活"*) apply_keepalive ;;
            *"启动音频"*) start_heartbeat ;;
            *"停止音频"*) stop_heartbeat ;;
            *"释放所有"*) revoke_permissions ;;
            *"返回"*) return ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    adb_menu_loop
fi