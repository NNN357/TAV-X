#!/bin/bash
# [METADATA]
# MODULE_NAME: 🛡️  ADB Keep-Alive
# MODULE_ENTRY: adb_menu_loop
# [END_METADATA]
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
        ui_print warn "ADB architecture error, attempting auto-fix..."
    fi
    ui_header "ADB Component Installation"
    if [ -d "$LEGACY_ADB_DIR" ]; then rm -rf "$LEGACY_ADB_DIR"; sed -i '/adb_tools\/platform-tools/d' "$HOME/.bashrc"; fi
    ui_print info "Installing android-tools..."
    if ui_spinner "Installing..." "pkg install android-tools -y"; then
        if command -v adb &> /dev/null; then ui_print success "ADB installed successfully!"; else ui_print error "Installation failed."; fi
    else ui_print error "Installation error."; fi
    ui_pause
}

check_adb_status() {
    if ! command -v adb &> /dev/null; then echo "${RED}Not Installed${NC}"; return 1; fi
    if timeout 2 adb devices 2>/dev/null | grep -q "device$"; then return 0; else return 1; fi
}

check_audio_deps() {
    local MISSING=""
    if ! command -v mpv &> /dev/null; then MISSING="$MISSING mpv"; fi
    if [ -n "$MISSING" ]; then
        ui_header "Installing Audio Components"
        ui_print info "Installing dependencies: $MISSING"
        pkg install $MISSING -y
    fi
}

ensure_silence_file() {
    if [ -f "$SILENCE_FILE" ] && [ -s "$SILENCE_FILE" ]; then return 0; fi
    ui_print warn "Silence file missing, rebuilding..."
    mkdir -p "$(dirname "$SILENCE_FILE")"
    local RESCUE_WAV="UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA="
    echo "$RESCUE_WAV" | base64 -d > "$SILENCE_FILE"
    if [ -s "$SILENCE_FILE" ]; then return 0; else ui_print error "Cannot generate silence file!"; return 1; fi
}

start_heartbeat() {
    check_audio_deps
    ensure_silence_file || { ui_pause; return; }
    if [ -f "$HEARTBEAT_PID" ]; then
        local old_pid=$(cat "$HEARTBEAT_PID")
        if kill -0 "$old_pid" 2>/dev/null; then ui_print warn "Audio heartbeat already running."; return; fi
    fi
    ui_header "Start Audio Heartbeat"
    echo -e "${YELLOW}Strategy: Simulate foreground media playback to force-elevate process priority.${NC}"
    echo ""
    setsid nohup bash -c "while true; do mpv --no-terminal --volume=0 --loop=inf \"$SILENCE_FILE\"; sleep 1; done" > /dev/null 2>&1 &
    echo $! > "$HEARTBEAT_PID"
    if command -v termux-wake-lock &> /dev/null; then termux-wake-lock; fi
    ui_print success "Heartbeat started! (PID: $(cat "$HEARTBEAT_PID"))"
    ui_pause
}

stop_heartbeat() {
    if [ -f "$HEARTBEAT_PID" ]; then
        local pid=$(cat "$HEARTBEAT_PID")
        kill -9 "$pid" 2>/dev/null
        rm -f "$HEARTBEAT_PID"
        pkill -f "mpv --no-terminal"
        if command -v termux-wake-unlock &> /dev/null; then termux-wake-unlock; fi
        ui_print success "Audio heartbeat stopped."
    else ui_print warn "Heartbeat not running."; fi
    ui_pause
}

pair_device() {
    ui_header "ADB Wireless Pairing"
    adb start-server >/dev/null 2>&1
    local host=$(ui_input "Enter IP:Port" "127.0.0.1:" "false")
    local code=$(ui_input "Enter 6-digit pairing code" "" "false")
    [[ -z "$code" ]] && return
    if ui_spinner "Pairing..." "adb pair '$host' '$code' > '$LOG_FILE' 2>&1"; then
        if grep -q "Successfully paired" "$LOG_FILE"; then ui_print success "Pairing successful!"; else ui_print error "Pairing failed."; fi
    else ui_print error "Connection timeout."; fi
    ui_pause
}

connect_adb() {
    ui_header "Connect ADB"
    if check_adb_status; then ui_print success "ADB already connected."; ui_pause; return; fi
    local target=$(ui_input "Enter IP:Port" "127.0.0.1:" "false")
    if [ -z "$target" ] || [ "$target" == "127.0.0.1:" ]; then return; fi
    if ui_spinner "Connecting to $target ..." "adb connect $target"; then
        sleep 1
        if check_adb_status; then ui_print success "Connection successful!"; else ui_print error "Connection failed."; fi
    fi
    ui_pause
}

get_device_info() {
    MANUFACTURER=$(adb shell getprop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')
    SDK_VER=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
    [ -z "$SDK_VER" ] && SDK_VER=0
}

apply_universal_fixes() {
    local PKG="com.termux"
    local SDK_VER=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
    [ -z "$SDK_VER" ] && SDK_VER=0
    
    if [ "$SDK_VER" -ge 32 ]; then
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
    
    if command -v termux-wake-lock &> /dev/null; then termux-wake-lock; fi
}

apply_vendor_fixes() {
    local PKG="com.termux"
    local MANUFACTURER=$(adb shell getprop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')
    local SDK_VER=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
    [ -z "$SDK_VER" ] && SDK_VER=0

    ui_print info "Detecting vendor strategy: $MANUFACTURER"
    
    case "$MANUFACTURER" in
        *huawei*|*honor*)
            ui_print info "Applying Huawei strategy..."
            adb shell pm disable-user --user 0 com.huawei.powergenie 2>/dev/null
            adb shell pm disable-user --user 0 com.huawei.android.hwaps 2>/dev/null
            adb shell am stopservice hwPfwService 2>/dev/null
            echo -e "${YELLOW}Tip: Please manually check Battery -> App Launch Management -> Termux -> Set to Manual${NC}"
            ;;
            
        *xiaomi*|*redmi*)
            ui_print info "Applying Xiaomi strategy..."
            adb shell pm disable-user --user 0 com.xiaomi.joyose 2>/dev/null
            adb shell pm disable-user --user 0 com.xiaomi.powerchecker 2>/dev/null
            adb shell am start -n com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity >/dev/null 2>&1
            echo -e "${YELLOW}Tip: System popup appeared, please enable [Auto-start] permission for Termux.${NC}"
            ;;
            
        *oppo*|*realme*|*oneplus*)
            ui_print info "Applying ColorOS strategy..."
            if [ "$SDK_VER" -ge 34 ]; then
                ui_print warn "Android 14+ detected: Skipping Athena disable (brick protection)."
                adb shell settings put global coloros_super_power_save 0
            else
                adb shell pm disable-user --user 0 com.coloros.athena 2>/dev/null
            fi
            adb shell am start -n com.coloros.safecenter/.startupapp.StartupAppListActivity >/dev/null 2>&1
            echo -e "${YELLOW}Tip: System popup appeared, please allow auto-start.${NC}"
            ;;
            
        *vivo*|*iqoo*)
            ui_print info "Applying OriginOS strategy..."
            adb shell pm disable-user --user 0 com.vivo.pem 2>/dev/null
            adb shell pm disable-user --user 0 com.vivo.abe 2>/dev/null
            adb shell am start -a android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS >/dev/null 2>&1
            ;;
            
        *)
            ui_print info "No specific vendor strategy, using universal optimization only."
            ;;
    esac
}

apply_smart_keepalive() {
    ui_header "Execute Smart Keep-Alive"
    if ! check_adb_status; then ui_print error "ADB not connected."; ui_pause; return; fi
    
    get_device_info
    echo -e "Device: ${CYAN}$MANUFACTURER${NC} (SDK: $SDK_VER)"
    echo "----------------------------------------"
    
    local SELF_SOURCE="source \"${BASH_SOURCE[0]}\""

    CHOICE=$(ui_menu "Select keep-alive mode" \
        "🛡️ Universal Keep-Alive (Recommended/Safe)" \
        "🔥 Aggressive Keep-Alive (Aggressive/Reversible)" \
        "🔙 Back" \
    )

    case "$CHOICE" in
        *"Universal"*)
            echo ""
            ui_print info "Executing universal optimization (AOSP)..."
            ui_spinner "Applying system parameters..." "$SELF_SOURCE; apply_universal_fixes"
            
            ui_print success "Universal keep-alive executed successfully!"
            echo -e "${YELLOW}Tip: Please restart your phone. If still killing background, try [Aggressive Keep-Alive].${NC}"
            ui_pause
            ;;
            
        *"Aggressive"*)
            echo ""
            echo -e "${RED}⚠️  Aggressive mode side effects warning:${NC}"
            echo -e "This mode will disable thermal/cloud control components, may cause heat or disable proprietary fast charging."
            
            if ! ui_confirm "I understand the risks, confirm execute?"; then 
                ui_print info "Cancelled."; ui_pause; return
            fi
            
            ui_spinner "Step 1/2: Applying universal strategy..." "$SELF_SOURCE; apply_universal_fixes"
            
            echo ""
            ui_print info "Step 2/2: Applying vendor strategy..."
            apply_vendor_fixes 
            
            echo ""
            ui_print success "Aggressive keep-alive executed successfully!"
            echo -e "${YELLOW}Important:${NC}"
            echo -e "1. Recommended to **restart phone** to fully apply changes."
            echo -e "2. No need to run again after restart, but need to restart audio heartbeat."
            ui_pause
            ;;
            
        *) return ;;
    esac
}

revert_all_changes() {
    ui_header "Revert/Factory Reset"
    if ! check_adb_status; then ui_print error "ADB not connected."; ui_pause; return; fi
    
    if ! ui_confirm "Are you sure you want to restore factory defaults?"; then return; fi
    
    ui_spinner "Performing full rollback..." "
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
    
    ui_print success "Default settings restored!"
    ui_pause
}

adb_menu_loop() {
    if [ "$OS_TYPE" == "LINUX" ]; then
        ui_print warn "Linux servers don't need keep-alive module."
        ui_pause; return
    fi

    check_dependency
    while true; do
        ui_header "ADB Smart Keep-Alive"
        
        local s_adb="${RED}● Not Connected${NC}"; check_adb_status && s_adb="${GREEN}● Connected${NC}"
        local s_audio="${RED}● Off${NC}"
        if [ -f "$HEARTBEAT_PID" ] && kill -0 $(cat "$HEARTBEAT_PID") 2>/dev/null; then 
            s_audio="${GREEN}● Running${NC}"
        fi
        
        echo -e "ADB Status: $s_adb | Audio Heartbeat: $s_audio"
        echo "----------------------------------------"
        
        CHOICE=$(ui_menu "Select action" \
            "🤝 Wireless Pairing" \
            "🔗 Connect ADB" \
            "⚡ Execute Smart Keep-Alive" \
            "🎵 Start Audio Heartbeat" \
            "🔇 Stop Audio Heartbeat" \
            "♻️  Revert All Optimizations" \
            "🔙 Back"
        )
        
        case "$CHOICE" in
            *"Wireless Pairing"*) pair_device ;;
            *"Connect ADB"*) connect_adb ;;
            *"Smart Keep-Alive"*) apply_smart_keepalive ;;
            *"Start Audio"*) start_heartbeat ;;
            *"Stop Audio"*) stop_heartbeat ;;
            *"Revert"*) revert_all_changes ;;
            *"Back"*) return ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    adb_menu_loop
fi