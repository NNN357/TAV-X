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
        if adb --version &> /dev/null; then return 0; fi
        ui_print warn "ADB 架构错误，尝试自动修复..."
    fi

    ui_header "ADB 组件安装"
    if [ -d "$LEGACY_ADB_DIR" ]; then 
        rm -rf "$LEGACY_ADB_DIR"
        [ -f "$HOME/.bashrc" ] && sed -i '/adb_tools\/platform-tools/d' "$HOME/.bashrc"
    fi

    ui_print info "正在安装 android-tools..."
    if ui_spinner "安装中..." "pkg install android-tools -y"; then
        if command -v adb &> /dev/null; then ui_print success "ADB 安装成功！"; else ui_print error "安装失败，请尝试运行 'pkg update' 后重试。"; fi
    else
        ui_print error "安装过程出错。";
    fi
    ui_pause
}

check_adb_status() {
    if ! command -v adb &> /dev/null; then echo "${RED}未安装${NC}"; return 1; fi
    if timeout 2 adb devices 2>/dev/null | grep -q "device$"; then return 0; else return 1; fi
}

check_audio_deps() {
    local MISSING=""
    if ! command -v mpv &> /dev/null; then MISSING="$MISSING mpv"; fi
    
    if [ -n "$MISSING" ]; then
        ui_header "安装音频组件"
        ui_print info "安装依赖: $MISSING"
        pkg install $MISSING -y
    fi
}

ensure_silence_file() {
    if [ -f "$SILENCE_FILE" ] && [ -s "$SILENCE_FILE" ]; then return 0; fi

    ui_print warn "静音文件丢失，正在重建..."
    mkdir -p "$(dirname "$SILENCE_FILE")"
    local RESCUE_WAV="UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA="
    echo "$RESCUE_WAV" | base64 -d > "$SILENCE_FILE"
    
    if [ -s "$SILENCE_FILE" ]; then return 0; else ui_print error "无法生成静音文件！"; return 1; fi
}

start_heartbeat() {
    check_audio_deps
    ensure_silence_file || { ui_pause; return; }
    
    if [ -f "$HEARTBEAT_PID" ]; then
        local old_pid=$(cat "$HEARTBEAT_PID")
        if kill -0 "$old_pid" 2>/dev/null; then ui_print warn "音频心跳已在运行。"; return; fi
    fi

    ui_header "启动音频心跳"
    echo -e "${YELLOW}策略：模拟前台媒体播放，强制提升进程优先级。${NC}"
    echo ""
    
    setsid nohup bash -c "while true; do mpv --no-terminal --volume=0 --loop=inf \"$SILENCE_FILE\"; sleep 1; done" > /dev/null 2>&1 &
    
    echo $! > "$HEARTBEAT_PID"
    
    if command -v termux-wake-lock &> /dev/null; then
        termux-wake-lock
    fi
    
    ui_print success "心跳已启动！(PID: $(cat "$HEARTBEAT_PID"))"
    ui_pause
}

stop_heartbeat() {
    if [ -f "$HEARTBEAT_PID" ]; then
        local pid=$(cat "$HEARTBEAT_PID")
        kill -9 "$pid" 2>/dev/null
        rm -f "$HEARTBEAT_PID"
        pkill -f "mpv --no-terminal"
        
        if command -v termux-wake-unlock &> /dev/null; then
            termux-wake-unlock
        fi
        
        ui_print success "音频心跳已停止。"
    else
        ui_print warn "心跳未运行。"
    fi
    ui_pause
}

pair_device() {
    ui_header "ADB 无线配对"
    echo -e "${YELLOW}前往: 开发者选项 -> 无线调试 -> 使用配对码配对${NC}"
    adb start-server >/dev/null 2>&1
    local host=$(ui_input "输入 IP:端口" "127.0.0.1:" "false")
    local code=$(ui_input "输入 6 位配对码" "" "false")
    [[ -z "$code" ]] && return
    
    if ui_spinner "正在配对..." "adb pair '$host' '$code' > '$LOG_FILE' 2>&1"; then
        if grep -q "Successfully paired" "$LOG_FILE"; then ui_print success "配对成功！"; else ui_print error "配对失败，请检查配对码。"; fi
    else ui_print error "连接超时。"; fi
    ui_pause
}

connect_adb() {
    ui_header "连接 ADB"
    if check_adb_status; then ui_print success "ADB 已连接。"; ui_pause; return; fi
    echo -e "${YELLOW}请输入无线调试界面的【IP地址和端口】${NC}"
    local target=$(ui_input "输入 IP:端口" "127.0.0.1:" "false")
    if [ -z "$target" ] || [ "$target" == "127.0.0.1:" ]; then return; fi
    
    if ui_spinner "正在连接 $target ..." "adb connect $target"; then
        sleep 1
        if check_adb_status; then ui_print success "连接成功！"; else ui_print error "连接失败。"; fi
    fi
    ui_pause
}

get_device_info() {
    MANUFACTURER=$(adb shell getprop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')
    SDK_VER=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
    [ -z "$SDK_VER" ] && SDK_VER=0
}

apply_universal_fixes() {
    # 修复：重新获取环境信息，防止子Shell变量丢失
    local PKG="com.termux"
    local SDK_VER=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
    [ -z "$SDK_VER" ] && SDK_VER=0

    ui_print info "执行通用 AOSP 优化 (SDK: $SDK_VER)..."
    
    if [ "$SDK_VER" -ge 32 ]; then
        ui_print info "Android 12+ 检测: 禁用幽灵进程杀手..."
        # 修复：移除引号，确保命令被正确解析
        adb shell device_config set_sync_disabled_for_tests persistent
        adb shell device_config put activity_manager max_phantom_processes 2147483647
        adb shell device_config put activity_manager settings_enable_monitor_phantom_procs false
    fi

    adb shell dumpsys deviceidle whitelist +$PKG >/dev/null 2>&1
    
    adb shell cmd appops set $PKG RUN_IN_BACKGROUND allow
    adb shell cmd appops set $PKG RUN_ANY_IN_BACKGROUND allow
    adb shell cmd appops set $PKG WAKE_LOCK allow
    adb shell cmd appops set $PKG START_FOREGROUND allow
    
    adb shell am set-standby-bucket $PKG active >/dev/null 2>&1
    
    if command -v termux-wake-lock &> /dev/null; then
        termux-wake-lock
        ui_print info "已申请 Termux 唤醒锁 (WakeLock)"
    fi
}

apply_vendor_fixes() {
    # 修复：重新获取环境信息
    local PKG="com.termux"
    local MANUFACTURER=$(adb shell getprop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')
    local SDK_VER=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
    [ -z "$SDK_VER" ] && SDK_VER=0

    ui_print info "检测厂商策略: $MANUFACTURER"
    
    case "$MANUFACTURER" in
        *huawei*|*honor*)
            ui_print info "应用华为/荣耀策略 (Safe Mode)..."
            adb shell pm disable-user --user 0 com.huawei.powergenie 2>/dev/null
            adb shell pm disable-user --user 0 com.huawei.android.hwaps 2>/dev/null
            adb shell am stopservice hwPfwService 2>/dev/null
            echo -e "${YELLOW}提示: 请手动检查 电池 -> 应用启动管理 -> Termux -> 改为手动管理${NC}"
            ;;
            
        *xiaomi*|*redmi*)
            ui_print info "应用小米/Redmi策略..."
            adb shell pm disable-user --user 0 com.xiaomi.joyose 2>/dev/null
            adb shell pm disable-user --user 0 com.xiaomi.powerchecker 2>/dev/null
            adb shell am start -n com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity >/dev/null 2>&1
            echo -e "${YELLOW}提示: 请在弹出的窗口中允许 Termux 自启动${NC}"
            ;;
            
        *oppo*|*realme*|*oneplus*)
            ui_print info "应用 ColorOS 策略..."
            if [ "$SDK_VER" -ge 34 ]; then
                ui_print warn "Android 14+ 检测: 跳过禁用 Athena (防砖保护)。"
                adb shell settings put global coloros_super_power_save 0
            else
                adb shell pm disable-user --user 0 com.coloros.athena 2>/dev/null
            fi
            adb shell am start -n com.coloros.safecenter/.startupapp.StartupAppListActivity >/dev/null 2>&1
            ;;
            
        *vivo*|*iqoo*)
            ui_print info "应用 OriginOS 策略..."
            adb shell pm disable-user --user 0 com.vivo.pem 2>/dev/null
            adb shell pm disable-user --user 0 com.vivo.abe 2>/dev/null
            adb shell am start -a android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS >/dev/null 2>&1
            ;;
            
        *)
            ui_print info "无特定厂商策略，仅使用通用优化。"
            ;;
    esac
}

apply_smart_keepalive() {
    ui_header "执行智能保活"
    if ! check_adb_status; then ui_print error "ADB 未连接。"; ui_pause; return; fi
    
    get_device_info
    echo -e "设备: ${CYAN}$MANUFACTURER${NC} (SDK: $SDK_VER)"
    echo "----------------------------------------"
    
    local TARGET_COMP="系统默认电源策略"
    case "$MANUFACTURER" in
        *xiaomi*|*redmi*) TARGET_COMP="Joyose (温控/云控)" ;;
        *oppo*|*realme*|*oneplus*) TARGET_COMP="Athena (系统守护)" ;;
        *huawei*|*honor*) TARGET_COMP="PowerGenie (省电精灵)" ;;
        *vivo*|*iqoo*) TARGET_COMP="PEM/ABE (省电管理)" ;;
    esac

    CHOICE=$(ui_menu "请选择保活方案" \
        "🛡️ 通用保活 (推荐/安全)" \
        "🔥 激进保活 (激进/可撤销)" \
        "🔙 返回" \
    )

    # 修复：调用时加载自身环境，确保函数在子Shell中可用
    local SELF_SOURCE="source \"$TAVX_DIR/modules/adb_keepalive.sh\""

    case "$CHOICE" in
        *"通用"*)
            echo ""
            ui_print info "正在执行通用优化 (AOSP)..."
            ui_spinner "应用策略中..." "$SELF_SOURCE; apply_universal_fixes"
            
            ui_print success "通用保活执行成功！"
            echo -e "${YELLOW}提示：请重启手机，如果之后频繁遇到杀后台，请尝试执行[激进保活]方案。${NC}"
            ui_pause
            ;;
            
        *"激进"*)
            echo ""
            echo -e "${RED}⚠️  激进模式副作用警告：${NC}"
            echo -e "此模式将禁用 [${TARGET_COMP}] 等组件，虽然保活效果极强，但可能导致："
            echo -e "1. 发热失控：高负载下无温控压制。"
            echo -e "2. 充电变慢：可能丢失私有快充协议。"
            echo -e "3. 系统卡顿：可能影响系统调度。"
            echo ""
            
            if ! ui_confirm "我已知晓风险，确认执行？"; then 
                ui_print info "已取消。"; ui_pause; return
            fi
            
            ui_spinner "正在应用通用策略..." "$SELF_SOURCE; apply_universal_fixes"
            ui_spinner "正在应用厂商策略..." "$SELF_SOURCE; apply_vendor_fixes"
            
            ui_print success "激进保活执行成功！"
            echo -e "${YELLOW}提示：${NC}"
            echo -e "1. **建议重启手机**以确保被禁用的组件彻底停止运行。"
            echo -e "2. 如需恢复，请使用本菜单的 [撤销所有优化] 功能。"
            ui_pause
            ;;
            
        *) return ;;
    esac
}

revert_all_changes() {
    ui_header "撤销/恢复出厂"
    if ! check_adb_status; then ui_print error "ADB 未连接。"; ui_pause; return; fi
    
    get_device_info
    echo -e "${RED}🚨 警告：全量回滚模式${NC}"
    echo -e "此操作将无视之前的设置，强制执行以下恢复："
    echo -e "1. 恢复 Android 原生电源限制 (幽灵进程杀手等)"
    echo -e "2. 尝试重新启用所有厂商组件 (华为/小米/OV等)"
    echo -e "3. 重置 Termux 的后台权限为默认"
    echo ""
    
    if ! ui_confirm "确定要恢复出厂默认配置吗？"; then return; fi
    
    ui_spinner "正在全量回滚..." "
        adb shell device_config set_sync_disabled_for_tests none
        adb shell device_config delete activity_manager max_phantom_processes
        adb shell device_config delete activity_manager settings_enable_monitor_phantom_procs
        adb shell dumpsys deviceidle whitelist -$PKG
        adb shell cmd appops set $PKG RUN_IN_BACKGROUND default
        adb shell cmd appops set $PKG RUN_ANY_IN_BACKGROUND default
        adb shell cmd appops set $PKG WAKE_LOCK default
        
        adb shell pm enable com.huawei.powergenie 2>/dev/null
        adb shell pm enable com.huawei.android.hwaps 2>/dev/null
        adb shell pm enable com.xiaomi.joyose 2>/dev/null
        adb shell pm enable com.xiaomi.powerchecker 2>/dev/null
        adb shell pm enable com.coloros.athena 2>/dev/null
        adb shell pm enable com.vivo.pem 2>/dev/null
        adb shell pm enable com.vivo.abe 2>/dev/null
        termux-wake-unlock
    "
    
    ui_print success "已恢复默认设置！"
    echo -e "${YELLOW}建议重启手机以重新加载系统组件。${NC}"
    ui_pause
}

adb_menu_loop() {
    if [ "$OS_TYPE" == "LINUX" ]; then
        ui_print warn "Linux 服务器不需要保活模块。"
        ui_pause; return
    fi

    check_dependency
    while true; do
        ui_header "ADB 智能保活 (AndroKeepAlive)"
        
        local s_adb="${RED}● 未连接${NC}"; check_adb_status && s_adb="${GREEN}● 已连接${NC}"
        local s_audio="${RED}● 关闭${NC}"
        if [ -f "$HEARTBEAT_PID" ] && kill -0 $(cat "$HEARTBEAT_PID") 2>/dev/null; then 
            s_audio="${GREEN}● 运行中${NC}"
        fi
        
        echo -e "ADB状态: $s_adb | 音频心跳: $s_audio"
        echo "----------------------------------------"
        
        CHOICE=$(ui_menu "请选择操作" \
            "🤝 无线配对" \
            "🔗 连接 ADB" \
            "⚡ 执行智能保活" \
            "🎵 启动音频心跳" \
            "🔇 停止音频心跳" \
            "♻️  撤销所有优化" \
            "🔙 返回上级"
        )
        
        case "$CHOICE" in
            *"无线配对"*) pair_device ;;
            *"连接 ADB"*) connect_adb ;;
            *"智能保活"*) apply_smart_keepalive ;;
            *"启动音频"*) start_heartbeat ;;
            *"停止音频"*) stop_heartbeat ;;
            *"撤销"*) revert_all_changes ;;
            *"返回"*) return ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    adb_menu_loop
fi