#!/bin/bash
# TAV-X Core: Service Launcher (V2 Optimized)

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/utils.sh"

CF_LOG="$INSTALL_DIR/cf_tunnel.log"
SERVER_LOG="$INSTALL_DIR/server.log"

# --- 服务管理 ---
stop_services() {
    pkill -f "node server.js"
    pkill -f "cloudflared"
    termux-wake-unlock 2>/dev/null
    info "服务已停止。"
}

# --- 获取链接 ---
wait_for_link() {
    info "正在请求 Cloudflare 边缘节点 (超时 15s)..."
    local attempt=1
    local max_attempts=15
    local link=""

    while [ $attempt -le $max_attempts ]; do
        if [ -f "$CF_LOG" ]; then
            link=$(grep -o "https://[-a-zA-Z0-9]*\.trycloudflare\.com" "$CF_LOG" | tail -n 1)
        fi

        if [ -n "$link" ]; then
            echo ""
            echo -e "${CYAN}========================================${NC}"
            echo -e "${GREEN}🌍 远程链接创建成功！${NC}"
            echo -e "${YELLOW}$link${NC}"
            echo -e "${CYAN}========================================${NC}"
            echo "提示：请复制上方链接在浏览器打开。"
            return 0
        fi

        # 进度条效果
        echo -ne "."
        sleep 1
        ((attempt++))
    done

    echo ""
    warn "获取链接超时。"
    warn "请尝试：1. 检查网络  2. 在菜单中查看 '穿透日志' 排查报错"
    return 1
}

# --- 日志子菜单 ---
view_logs_menu() {
    while true; do
        header "日志监控中心"
        echo -e "  1. 📜 酒馆运行日志"
        echo -e "  2. 🚇 穿透隧道日志"
        echo -e "  0. 返回"
        echo ""
        read -p "选择: " log_c
        case $log_c in
            1)
                if [ -f "$SERVER_LOG" ]; then
                    clear; echo -e "${CYAN}--- 按 Ctrl+C 退出监控 ---${NC}"
                    tail -n 20 -f "$SERVER_LOG"
                else
                    warn "暂无酒馆日志"
                    sleep 1
                fi
                ;;
            2)
                if [ -f "$CF_LOG" ]; then
                    clear; echo -e "${CYAN}--- 按 Ctrl+C 退出监控 ---${NC}"
                    cat "$CF_LOG"
                    echo -e "\n${YELLOW}--- 实时监控中 ---${NC}"
                    tail -n 10 -f "$CF_LOG"
                else
                    warn "暂无穿透日志 (服务未启动?)"
                    sleep 1
                fi
                ;;
            0) return ;;
            *) warn "无效输入"; sleep 0.5 ;;
        esac
    done
}

# --- 启动菜单 ---
start_menu() {
    while true; do
        header "启动中心"
        
        if pgrep -f "cloudflared" >/dev/null; then
            STATUS_MSG="${GREEN}● 穿透运行中${NC}"
        elif pgrep -f "node server.js" >/dev/null; then
            STATUS_MSG="${GREEN}● 本地运行中${NC}"
        else
            STATUS_MSG="${RED}● 已停止${NC}"
        fi
        echo -e "当前状态: $STATUS_MSG"
        echo ""

        echo -e "  1. 🏠 本地模式 - 仅本机"
        echo -e "  2. 🌍 远程穿透 - 生成链接"
        echo -e "  3. 🔍 重新获取链接"
        echo -e "  4. 📜 日志监控"
        echo -e "  5. 🛑 停止所有服务"
        echo -e "  0. 返回"
        echo ""
        read -p "选择: " l_choice

        case $l_choice in
            1)
                stop_services
                info "启动本地服务..."
                cd "$INSTALL_DIR" || return
                termux-wake-lock
                rm -f "$SERVER_LOG"
                nohup node server.js > "$SERVER_LOG" 2>&1 &
                success "本地服务已启动: http://127.0.0.1:8000"
                pause
                ;;
            2)
                stop_services
                info "启动穿透模式..."
                cd "$INSTALL_DIR" || return
                termux-wake-lock
                rm -f "$SERVER_LOG" "$CF_LOG"
                
                # 启动酒馆
                nohup node server.js > "$SERVER_LOG" 2>&1 &
                sleep 2
                
                # 启动 CF
                nohup cloudflared tunnel --protocol http2 --url http://127.0.0.1:8000 --no-autoupdate > "$CF_LOG" 2>&1 &
                
                # 智能等待
                wait_for_link
                pause
                ;;
            3)
                wait_for_link
                pause
                ;;
            4)
                view_logs_menu
                ;;
            5)
                stop_services
                sleep 1
                ;;
            0) return ;;
        esac
    done
}
