#!/bin/bash
# TAV-X Core: Dependency Manager

source "$TAVX_DIR/core/ui.sh"

check_dependencies() {
    if [ "$DEPS_CHECKED" == "true" ]; then return 0; fi

    local MISSING_PKGS=""
    
    if command -v node &> /dev/null && \
       command -v git &> /dev/null && \
       command -v cloudflared &> /dev/null && \
       command -v gum &> /dev/null && \
       command -v tar &> /dev/null; then
        export DEPS_CHECKED="true"
        return 0
    fi

    ui_header "Environment Initialization"
    echo -e "${BLUE}[INFO]${NC} Checking all components..."

    if ! command -v node &> /dev/null; then 
        echo -e "${YELLOW}[WARN]${NC} Node.js not found (Core Engine)"
        MISSING_PKGS="$MISSING_PKGS nodejs-lts"
    fi

    if ! command -v git &> /dev/null; then 
        echo -e "${YELLOW}[WARN]${NC} Git not found (Version Control)"
        MISSING_PKGS="$MISSING_PKGS git"
    fi
    
    if ! command -v cloudflared &> /dev/null; then 
        echo -e "${YELLOW}[WARN]${NC} Cloudflared not found (Tunnel)"
        MISSING_PKGS="$MISSING_PKGS cloudflared"
    fi

    if ! command -v gum &> /dev/null; then
        echo -e "${YELLOW}[WARN]${NC} Gum not found (UI Engine)"
        MISSING_PKGS="$MISSING_PKGS gum"
    fi

    if ! command -v tar &> /dev/null; then
        echo -e "${YELLOW}[WARN]${NC} Tar not found (Backup Tool)"
        MISSING_PKGS="$MISSING_PKGS tar"
    fi

    if [ -n "$MISSING_PKGS" ]; then
        echo -e "${BLUE}[INFO]${NC} Missing components detected, auto-installing: $MISSING_PKGS"
        
        yes | pkg update -y -o Dpkg::Options::="--force-confold"
        yes | pkg install $MISSING_PKGS -y -o Dpkg::Options::="--force-confold"
        
        if command -v node &> /dev/null && \
           command -v git &> /dev/null && \
           command -v cloudflared &> /dev/null && \
           command -v gum &> /dev/null && \
           command -v tar &> /dev/null; then
            
            echo -e "${GREEN}[DONE]${NC} Environment fully repaired!"
            export DEPS_CHECKED="true"
            read -n 1 -s -r -p "Press any key to continue..."
        else
            echo -e "${RED}[ERROR]${NC} Environment repair incomplete! Some components failed to install."
            echo -e "${YELLOW}Try switching networks or run manually: pkg install $MISSING_PKGS${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}[DONE]${NC} Environment complete."
        export DEPS_CHECKED="true"
    fi
}