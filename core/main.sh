#!/bin/bash
# TAV-X Core: Main Logic

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"
source "$TAVX_DIR/core/deps.sh"
source "$TAVX_DIR/core/security.sh"
source "$TAVX_DIR/core/plugins.sh"
source "$TAVX_DIR/core/backup.sh"
source "$TAVX_DIR/core/updater.sh"
source "$TAVX_DIR/core/install.sh"
source "$TAVX_DIR/core/launcher.sh"
source "$TAVX_DIR/core/uninstall.sh"
source "$TAVX_DIR/core/about.sh"

check_dependencies
check_for_updates
send_analytics

# --- 动态模块加载器 ---
load_advanced_tools_menu() {
    local module_files=()
    local module_names=()
    local module_entries=()
    local menu_options=()

    # 1. 扫描 modules 目录下的所有 .sh 文件
    # 使用 nullglob 防止目录为空时报错
    shopt -s nullglob
    for file in "$TAVX_DIR/modules/"*.sh; do
        # 检查文件是否包含元数据标记
        if grep -q "\[METADATA\]" "$file"; then
            # 提取 MODULE_NAME 和 MODULE_ENTRY
            # 使用 grep 提取行，cut 分割，sed 去除前后空格
            local m_name=$(grep "MODULE_NAME:" "$file" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            local m_entry=$(grep "MODULE_ENTRY:" "$file" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # 只有当名称和入口都存在时才添加到菜单
            if [ -n "$m_name" ] && [ -n "$m_entry" ]; then
                module_files+=("$file")
                module_names+=("$m_name")
                module_entries+=("$m_entry")
                menu_options+=("$m_name")
            fi
        fi
    done
    shopt -u nullglob

    # 如果没有找到任何模块
    if [ ${#menu_options[@]} -eq 0 ]; then
        ui_print warn "未检测到有效的工具模块。"
        echo -e "${YELLOW}请检查 modules/ 目录下脚本是否包含 [METADATA] 头部信息。${NC}"
        ui_pause
        return
    fi

    menu_options+=("🔙 返回上级")

    # 2. 显示动态菜单
    # 循环直到用户选择返回，实现子菜单常驻
    while true; do
        local choice=$(ui_menu "高级工具箱 (插件化)" "${menu_options[@]}")

        if [[ "$choice" == *"返回上级"* ]]; then
            return
        fi

        # 3. 匹配并执行
        local matched=false
        for i in "${!module_names[@]}"; do
            if [[ "${module_names[$i]}" == "$choice" ]]; then
                local target_file="${module_files[$i]}"
                local target_entry="${module_entries[$i]}"
                
                # 加载脚本环境
                source "$target_file"
                
                # 检查入口函数是否存在
                if command -v "$target_entry" &> /dev/null; then
                    $target_entry
                else
                    ui_print error "模块错误：找不到入口函数 '$target_entry'"
                    ui_pause
                fi
                matched=true
                break
            fi
        done
        
        # 理论上不会运行到这里，但做个防守
        if [ "$matched" = false ]; then
            ui_print error "无法加载该模块，请重试。"
            ui_pause
        fi
    done
}

while true; do
    S_ST=0; S_CF=0; S_ADB=0; S_CLEWD=0; S_GEMINI=0; S_AUDIO=0
    pgrep -f "node server.js" >/dev/null && S_ST=1
    pgrep -f "cloudflared" >/dev/null && S_CF=1
    command -v adb &>/dev/null && adb devices 2>/dev/null | grep -q "device$" && S_ADB=1
    pgrep -f "clewd" >/dev/null && S_CLEWD=1
    pgrep -f "run.py" >/dev/null && S_GEMINI=1
    if [ -f "$TAVX_DIR/.audio_heartbeat.pid" ] && kill -0 $(cat "$TAVX_DIR/.audio_heartbeat.pid") 2>/dev/null; then
        S_AUDIO=1
    fi

    NET_DL="自动优选"
    if [ -f "$NETWORK_CONFIG" ]; then
        CONF=$(cat "$NETWORK_CONFIG"); TYPE=${CONF%%|*}; VAL=${CONF#*|}
        [ ${#VAL} -gt 25 ] && VAL="...${VAL: -22}"
        [ "$TYPE" == "PROXY" ] && NET_DL="本地代理 ($VAL)"
        [ "$TYPE" == "MIRROR" ] && NET_DL="指定镜像 ($VAL)"
    fi

    NET_API="直连 (System)"
    if [ -f "$CONFIG_FILE" ]; then
        if grep -A 4 "requestProxy:" "$CONFIG_FILE" | grep -q "enabled: true"; then
            URL=$(grep -A 4 "requestProxy:" "$CONFIG_FILE" | grep "url:" | awk '{print $2}' | tr -d '"')
            [ -z "$URL" ] && URL="已开启"
            NET_API="代理 ($URL)"
        fi
    fi

    ui_header ""
    ui_dashboard "$S_ST" "$S_CF" "$S_ADB" "$NET_DL" "$NET_API" "$S_CLEWD" "$S_GEMINI" "$S_AUDIO"

    OPT_UPD="🔄 安装与更新"
    [ -f "$TAVX_DIR/.update_available" ] && OPT_UPD="🔄 安装与更新 🔔"

    CHOICE=$(ui_menu "功能导航" \
        "🚀 启动服务" \
        "$OPT_UPD" \
        "⚙️  系统设置" \
        "🧩 插件管理" \
        "🌐 网络设置" \
        "💾 备份与恢复" \
        "🛠️  高级工具" \
        "💡 帮助与支持" \
        "🚪 退出程序"
    )

    case "$CHOICE" in
        *"启动服务")
            if [ ! -d "$INSTALL_DIR" ]; then ui_print warn "请先安装酒馆！"; ui_pause; else start_menu; fi ;;
        *"安装与更新"*) update_center_menu ;;
        *"系统设置") security_menu ;;
        *"插件管理") plugin_menu ;;
        *"网络设置") configure_download_network ;;
        *"备份与恢复") backup_menu ;;
        
        # --- 改动：统一调用动态加载器 ---
        *"高级工具") load_advanced_tools_menu ;;
        
        *"帮助与支持"*) show_about_page ;;
            
        *"退出程序"*) 
            EXIT_OPT=$(ui_menu "请选择退出方式" \
                "🏃 保持后台运行" \
                "🛑 结束所有服务并退出" \
                "🔙 取消" \
            )
            
            case "$EXIT_OPT" in
                *"保持后台"*)
                    ui_print info "程序已最小化，服务继续在后台运行。"
                    ui_print info "下次输入 'st' 即可唤回菜单。"
                    exit 0 
                    ;;
                *"结束所有"*)
                    echo ""
                    if ui_confirm "确定要关闭所有服务（酒馆、穿透、保活等）吗？"; then
                        ui_spinner "正在停止所有进程..." "
                            if [ -f '$TAVX_DIR/.audio_heartbeat.pid' ]; then
                                HB_PID=\$(cat '$TAVX_DIR/.audio_heartbeat.pid')
                                kill -9 \$HB_PID >/dev/null 2>&1
                                rm -f '$TAVX_DIR/.audio_heartbeat.pid'
                            fi
                            pkill -f 'mpv --no-terminal'
                            adb kill-server >/dev/null 2>&1
                            pkill -f 'adb'
                            pkill -f 'node server.js'
                            pkill -f 'cloudflared'
                            pkill -f 'clewd'
                            pkill -f 'run.py'
                            
                            termux-wake-unlock 2>/dev/null
                            rm -f '$TAVX_DIR/.temp_link'
                        "
                        ui_print success "所有服务已停止，资源已释放。"
                        exit 0
                    else
                        ui_print info "操作已取消。"
                    fi
                    ;;
                *) ;;
            esac
            ;;
            
        *) exit 0 ;;
    esac
done