#!/bin/bash
# TAV-X Core: Main Logic Entry

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/utils.sh"
source "$TAVX_DIR/core/deps.sh"
# 预加载模块
source "$TAVX_DIR/core/install.sh"
source "$TAVX_DIR/core/launcher.sh"

# 自动检查环境
check_dependencies

while true; do
    print_banner
    
    if [ -d "$INSTALL_DIR" ]; then 
        ST_STATUS="${GREEN}已安装${NC}"
    else 
        ST_STATUS="${YELLOW}未安装${NC}"
    fi
    echo -e "酒馆状态: $ST_STATUS"
    echo ""

    echo -e "  1. 🚀 启动服务 (Launch)"
    echo -e "  2. 📥 安装/更新 (Install)"
    echo -e "  3. 🛠️  工具箱 (Tools)"
    echo -e "  0. 退出 (Exit)"
    echo ""
    
    read -p "请选择: " choice
    
    case $choice in
        1) 
            if [ ! -d "$INSTALL_DIR" ]; then
                warn "请先安装酒馆！"
                sleep 1
            else
                start_menu 
            fi
            ;;
        2) 
            install_sillytavern 
            ;;
        3)
            # 工具箱逻辑
            while true; do
                header "工具箱"
                echo -e "  1. 🛡️  ADB 保活 (ADB Keepalive)"
                echo -e "  0. 返回上级"
                read -p "选择: " t_choice
                case $t_choice in
                    1) bash "$TAVX_DIR/modules/adb_keepalive.sh";;
                    0) break ;;
                esac
            done
            ;;
        0) 
            echo -e "${CYAN}See you next time space cowboy...${NC}"
            exit 0 
            ;;
        *) warn "无效输入"; sleep 0.5 ;;
    esac
done
