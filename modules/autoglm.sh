#!/bin/bash
# [METADATA]
# MODULE_NAME: 🤖 AutoGLM Agent
# MODULE_ENTRY: autoglm_menu
# [END_METADATA]

source "$TAVX_DIR/core/utils.sh"

# --- Variable Definitions ---
AUTOGLM_DIR="$TAVX_DIR/autoglm"
VENV_DIR="$AUTOGLM_DIR/venv"
CONFIG_FILE="$TAVX_DIR/config/autoglm.env"
INSTALL_LOG="$TAVX_DIR/autoglm_install.log"
LAUNCHER_SCRIPT="$TAVX_DIR/core/ai_launcher.sh"
REPO_URL="Future-404/Open-AutoGLM"
ADB_KEYBOARD_URL="https://github.com/senzhk/ADBKeyBoard/raw/master/ADBKeyboard.apk"
TERMUX_API_PKG="com.termux.api"

# --- Helper Functions ---
check_uv_installed() {
    if command -v uv &> /dev/null; then return 0; fi
    
    ui_print info "Preparing to install uv (local compile mode)..."
    echo "----------------------------------------"
    echo ">>> [Setup] Completing Rust build environment..."
    
    pkg install rust binutils -y
    
    echo ">>> [Setup] Checking proxy support..."
    pip install pysocks
    
    echo ">>> [Build] Compiling uv (this takes a while, please wait)..."
    export CARGO_BUILD_JOBS=1
    if pip install uv; then
        ui_print success "uv installed successfully (Native)"
        return 0
    else
        ui_print error "uv installation failed, check errors above."
        return 1
    fi
}

check_adb_keyboard() {
    if adb shell ime list -s | grep -q "com.android.adbkeyboard/.AdbIME"; then return 0; fi
    ui_print warn "ADB Keyboard not detected"
    if ui_confirm "Auto download and install ADB Keyboard?"; then
        local apk_path="$TAVX_DIR/temp_adbkeyboard.apk"
        prepare_network_strategy "$ADB_KEYBOARD_URL"
        if download_file_smart "$ADB_KEYBOARD_URL" "$apk_path"; then
            if adb install -r "$apk_path"; then
                rm "$apk_path"
                ui_print success "Installation successful!"
                adb shell ime enable com.android.adbkeyboard/.AdbIME >/dev/null 2>&1
                adb shell ime set com.android.adbkeyboard/.AdbIME >/dev/null 2>&1
                return 0
            fi
        fi
        ui_print error "Installation failed"
    fi
    return 1
}

# --- Launcher Generation ---
create_ai_launcher() {
cat << EOF > "$LAUNCHER_SCRIPT"
#!/bin/bash
export TAVX_DIR="$TAVX_DIR"
EOF

cat << 'EOF' >> "$LAUNCHER_SCRIPT"

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

CONFIG_FILE="$TAVX_DIR/config/autoglm.env"
AUTOGLM_DIR="$TAVX_DIR/autoglm"
VENV_DIR="$AUTOGLM_DIR/venv"

send_feedback() {
    local status="$1"; local msg="$2"
    local clean_msg=$(echo "$msg" | tr '()' '[]' | tr '"' ' ' | tr "'" " ")
    local enable_feedback="${PHONE_AGENT_FEEDBACK:-true}"
    
    [ "$status" == "success" ] && ui_print success "$msg" || ui_print error "$msg"
    [ "$enable_feedback" != "true" ] && return 0

    if [ "$status" == "success" ]; then
        command -v termux-toast &>/dev/null && termux-toast -g bottom "✅ Task Complete"
        adb shell cmd notification post -S bigtext -t "AutoGLM Complete" "AutoGLM" "$clean_msg" >/dev/null 2>&1
        command -v termux-vibrate &>/dev/null && { termux-vibrate -d 80; sleep 0.15; termux-vibrate -d 80; }
    else
        command -v termux-toast &>/dev/null && termux-toast -g bottom "❌ Task Interrupted"
        adb shell cmd notification post -S bigtext -t "AutoGLM Failed" "AutoGLM" "$clean_msg" >/dev/null 2>&1
        command -v termux-vibrate &>/dev/null && termux-vibrate -d 400
    fi
}

check_dependencies() {
    if ! adb devices | grep -q "device$"; then
        ui_print error "ADB not connected, redirecting to fix..."
        sleep 1
        source "$TAVX_DIR/modules/adb_keepalive.sh"
        adb_menu_loop
        if ! adb devices | grep -q "device$"; then ui_print error "Connection failed"; exit 1; fi
    fi
}

main() {
    if [ ! -d "$AUTOGLM_DIR" ]; then ui_print error "Not installed"; exit 1; fi
    check_dependencies
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
    source "$VENV_DIR/bin/activate"

    local enable_feedback="${PHONE_AGENT_FEEDBACK:-true}"
    if [ "$enable_feedback" == "true" ] && command -v termux-toast &> /dev/null; then
        termux-toast -g bottom "🚀 AutoGLM started..."
    fi

    echo ""; ui_print success "🚀 Agent ready!"
    echo -e "${CYAN}>>> 3 second countdown...${NC}"; sleep 3
    cd "$AUTOGLM_DIR" || exit
    
    if [ $# -eq 0 ]; then python main.py; else python main.py "$*"; fi
    
    EXIT_CODE=$?
    echo ""
    [ $EXIT_CODE -eq 0 ] && send_feedback "success" "Task execution complete." || send_feedback "error" "Program exited abnormally [Code $EXIT_CODE]."
}
main "$@"
EOF
    chmod +x "$LAUNCHER_SCRIPT"
    local ALIAS_CMD="alias ai='bash $LAUNCHER_SCRIPT'"
    if ! grep -Fq "alias ai=" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"; echo "$ALIAS_CMD" >> "$HOME/.bashrc"
    fi
}

# --- Core Process ---
install_autoglm() {
    ui_header "Deploy Open-AutoGLM"
    rm -f "$INSTALL_LOG"; touch "$INSTALL_LOG"
    
    ui_print info "Starting fully automatic installation..."
    echo -e "${YELLOW}Please watch the log below.${NC}"
    echo "----------------------------------------"

    (
        set -e
        echo ">>> [Phase 1] Installing system base libraries..."
        local SYS_PKGS="termux-api python-numpy python-pillow python-cryptography libjpeg-turbo libpng libxml2 libxslt clang make rust binutils"
        pkg install root-repo science-repo -y
        pkg install -y -o Dpkg::Options::="--force-confold" $SYS_PKGS
    ) >> "$INSTALL_LOG" 2>&1
    
    check_uv_installed || return

    (
        set -e
        echo ">>> [Phase 3] Downloading core code..."
        if [ -d "$AUTOGLM_DIR" ]; then rm -rf "$AUTOGLM_DIR"; fi
        
        auto_load_proxy_env
        git clone --depth 1 "https://github.com/$REPO_URL" "$AUTOGLM_DIR"
        cd "$AUTOGLM_DIR" || exit 1
        
        echo ">>> [Phase 4] Creating virtual environment..."
        python -m venv "$VENV_DIR" --system-site-packages
        source "$VENV_DIR/bin/activate"
        
        echo ">>> [Phase 5] Installing dependencies..."
        
        local WHEEL_URL="https://github.com/NNN357/TAV-X/releases/download/assets-v1/autoglm_wheels.tar.gz"
        local USE_OFFLINE=false
        
        if download_file_smart "$WHEEL_URL" "wheels.tar.gz"; then
            if tar -xzf wheels.tar.gz; then USE_OFFLINE=true; fi
            rm -f wheels.tar.gz
        fi
        
        cp requirements.txt requirements.tmp
        sed -i '/numpy/d' requirements.tmp
        sed -i '/Pillow/d' requirements.tmp
        sed -i '/cryptography/d' requirements.tmp
        
        export CARGO_BUILD_JOBS=1
        
        if [ "$USE_OFFLINE" == "true" ] && [ -d "wheels" ]; then
            echo ">>> [Mode] 🚀 Hybrid fast install (UV Native)..."
            uv pip install --find-links=./wheels -r requirements.tmp
            uv pip install --find-links=./wheels "httpx[socks]"
            uv pip install --find-links=./wheels -e .
            rm -rf wheels
        else
            echo ">>> [Mode] 🐢 Online compile install (UV Native)..."
            if ! uv pip install -r requirements.tmp; then
                 uv pip install -r requirements.tmp -i https://pypi.tuna.tsinghua.edu.cn/simple
            fi
            uv pip install "httpx[socks]"
            uv pip install -e .
        fi
        rm requirements.tmp
        
        echo ">>> ✅ All installation steps complete!"
    ) >> "$INSTALL_LOG" 2>&1 &
    
    safe_log_monitor "$INSTALL_LOG"
    
    if adb devices | grep -q "device$"; then check_adb_keyboard; fi
    if ! adb shell pm list packages | grep -q "com.termux.api"; then
        ui_print warn "Recommend installing Termux:API app"
    fi
    
    create_ai_launcher
    ui_print success "Deployment complete! Type 'ai' to start."
    ui_pause
}

configure_autoglm() {
    ui_header "AutoGLM Configuration"
    local current_key=""
    local current_base=""
    local current_model="autoglm-phone"
    local current_feedback="true"
    if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"
        current_key="$PHONE_AGENT_API_KEY"; current_base="$PHONE_AGENT_BASE_URL"; [ -n "$PHONE_AGENT_MODEL" ] && current_model="$PHONE_AGENT_MODEL"; [ -n "$PHONE_AGENT_FEEDBACK" ] && current_feedback="$PHONE_AGENT_FEEDBACK"; fi
    
    echo -e "${CYAN}Configuration:${NC}"
    local new_key=$(ui_input "API Key" "$current_key" "true")
    local new_base=$(ui_input "Base URL" "${current_base:-https://open.bigmodel.cn/api/paas/v4}" "false")
    local new_model=$(ui_input "Model Name" "${current_model:-glm-4v-flash}" "false")
    echo -e "${YELLOW}Enable feedback (notifications/vibration/toast)?${NC}"
    local new_feedback=$(ui_input "Enable Feedback (true/false)" "$current_feedback" "false")
    
    echo "export PHONE_AGENT_API_KEY='$new_key'" > "$CONFIG_FILE"
    echo "export PHONE_AGENT_BASE_URL='$new_base'" >> "$CONFIG_FILE"
    echo "export PHONE_AGENT_MODEL='$new_model'" >> "$CONFIG_FILE"
    echo "export PHONE_AGENT_LANG='cn'" >> "$CONFIG_FILE"
    echo "export PHONE_AGENT_FEEDBACK='$new_feedback'" >> "$CONFIG_FILE"
    
    create_ai_launcher
    ui_print success "Saved"; ui_pause
}

start_autoglm() {
    if [ ! -f "$LAUNCHER_SCRIPT" ]; then create_ai_launcher; fi
    bash "$LAUNCHER_SCRIPT"
    ui_pause
}

autoglm_menu() {
    while true; do
        ui_header "AutoGLM Agent"
        local status="${RED}Not Installed${NC}"
        [ -d "$AUTOGLM_DIR" ] && status="${GREEN}Installed${NC}"
        echo -e "Status: $status"
        echo -e "Tip: After install, use global command ${CYAN}ai${NC} to quick start"
        echo "----------------------------------------"
        CHOICE=$(ui_menu "Action" "🚀 Start" "⚙️  Configure/Settings" "📥 Install/Reinstall" "🔙 Back")
        case "$CHOICE" in
            *"Start"*) start_autoglm ;;
            *"Configure"*) configure_autoglm ;;
            *"Install"*) install_autoglm ;;
            *"Back"*) return ;;
        esac
    done
}