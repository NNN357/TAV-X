# --- 代理设置模块 ---

configure_proxy() {
    echo -e "${CYAN}=== 🌐 代理/梯子设置向导 ===${NC}"
    echo -e "该功能让酒馆通过您的 VPN (Clash/v2ray等) 访问 API，"
    echo -e "同时保持远程 Cloudflare 连接稳定。"
    echo ""
    
    # 1. 询问端口 (这是最关键的)
    echo -e "${YELLOW}第一步: 请输入您的 VPN 软件本地端口${NC}"
    echo -e "如果不清楚，请去您的 VPN 软件设置里查看 'HTTP 端口' 或 'SOCKS 端口'。"
    echo -e "常见默认端口: Clash(7890), v2rayNG(10808), Surfboard(6152)"
    read -p "请输入端口号 (直接回车默认 7890): " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-7890} # 默认值 7890

    # 2. 询问协议 (解决您的通用性担忧)
    echo ""
    echo -e "${YELLOW}第二步: 请选择代理协议${NC}"
    echo -e "❓ 如果您不确定，请直接回车选择 HTTP，这适用于 99% 的情况。"
    echo -e "1) HTTP   (✅ 推荐 - 兼容性最好，适用于 Clash/Surfboard/Mixed)"
    echo -e "2) SOCKS5 (适用于 v2rayNG 或纯 SOCKS 模式)"
    read -p "请选择 (1/2): " PROTO_CHOICE

    case $PROTO_CHOICE in
        2) PROTOCOL="socks5" ;;
        *) PROTOCOL="http" ;; # 默认 HTTP
    esac

    # 构造完整的 URL
    PROXY_URL="${PROTOCOL}://127.0.0.1:${PROXY_PORT}"

    echo ""
    echo -e "${CYAN}>>> 正在配置: $PROXY_URL ...${NC}"

    # 3. 核心修改逻辑 (精准修改 config.yaml)
    if [ -f "$CONFIG_FILE" ]; then
        # 先备份
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        
        # 这里的逻辑是：先找到 requestProxy 区块，然后修改里面的 enabled 和 url
        # 使用 python 或 node 做 yaml 修改最稳，但为了不依赖环境，我们用 sed
        # 1. 开启代理 (enabled: true) - 只匹配 requestProxy 下面的那一行
        sed -i '/^requestProxy:/,/^  url:/ s/enabled: false/enabled: true/' "$CONFIG_FILE"
        
        # 2. 修改 URL (整行替换)
        # 匹配以 '  url:' 开头，且在 requestProxy 附近的行
        sed -i "/^requestProxy:/,/^  bypass:/ s|^  url:.*|  url: \"$PROXY_URL\"|" "$CONFIG_FILE"

        echo -e "${GREEN}√ 配置写入成功！${NC}"
        echo -e "${YELLOW}请重启酒馆 (选项 4 -> 选项 1) 以生效。${NC}"
    else
        echo -e "${RED}错误：找不到 config.yaml 文件！${NC}"
    fi
    
    read -p "按回车返回..."
}

disable_proxy() {
    if [ -f "$CONFIG_FILE" ]; then
        # 只把 requestProxy 下面的 true 改成 false
        sed -i '/^requestProxy:/,/^  url:/ s/enabled: true/enabled: false/' "$CONFIG_FILE"
        echo -e "${GREEN}√ 代理已关闭 (enabled: false)${NC}"
        echo -e "${YELLOW}请重启酒馆以生效。${NC}"
    else
        echo -e "${RED}找不到配置文件。${NC}"
    fi
    read -p "按回车返回..."
}

# --- 菜单显示逻辑 (添加到 show_menu 里) ---
# 在 show_menu 函数里，case $choice 之前，增加这个选项：
# echo -e "  7. 🌐 设置 API 代理 (解决连不上 API)"
#
# 在 case $choice in 里面增加：
# 7) configure_proxy ;; 
# 8) disable_proxy ;; # 您可以做个子菜单，或者直接分开