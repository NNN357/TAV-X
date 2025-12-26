#!/bin/bash
# TAV-X Core: Backup & Restore

source "$TAVX_DIR/core/env.sh"
source "$TAVX_DIR/core/ui.sh"
source "$TAVX_DIR/core/utils.sh"

EXTERNAL_DIR="$HOME/storage/downloads/ST_Backup"

check_storage_permission() {
    if [ ! -d "$HOME/storage" ]; then
        ui_print warn "Storage mapping not detected, attempting to create..."
        termux-setup-storage
        sleep 3
    fi

    if [ ! -d "$HOME/storage/downloads" ]; then
        ui_print error "Cannot access storage directory (Permission Denied)"
        ui_print info "Please try running manually: termux-setup-storage"
        return 1
    fi
    mkdir -p "$EXTERNAL_DIR"
    return 0
}

perform_backup() {
    ui_header "Data Backup"
    if [ ! -d "$INSTALL_DIR" ]; then ui_print error "Please install SillyTavern first!"; ui_pause; return; fi
    check_storage_permission || { ui_pause; return; }

    cd "$INSTALL_DIR" || return
    
    local TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
    [ -z "$TIMESTAMP" ] && TIMESTAMP=$(date +%s)

    local BACKUP_FILE="$EXTERNAL_DIR/ST_Data_${TIMESTAMP}.tar.gz"
    
    local TARGETS="data"
    [ -f "secrets.json" ] && TARGETS="$TARGETS secrets.json"
    [ -d "plugins" ] && TARGETS="$TARGETS plugins"
    if [ -d "public/scripts/extensions/third-party" ]; then
        TARGETS="$TARGETS public/scripts/extensions/third-party"
    fi
    
    echo -e "${CYAN}Backing up the following:${NC}"
    echo -e "$TARGETS" | tr ' ' '\n' | sed 's/^/  - /'
    echo ""

    if ui_spinner "Packing data..." "tar -czf '$BACKUP_FILE' $TARGETS 2>/dev/null"; then
        ui_print success "Backup successful!"
        echo -e "Location: ${GREEN}Download/ST_Backup/$(basename "$BACKUP_FILE")${NC}"
        echo -e "${YELLOW}Note: This backup doesn't include config.yaml, system settings will reset after restore.${NC}"
    else
        ui_print error "Backup failed."
    fi
    ui_pause
}

perform_restore() {
    ui_header "Data Restore"
    if [ ! -d "$INSTALL_DIR" ]; then ui_print error "Please install SillyTavern first!"; ui_pause; return; fi
    check_storage_permission || { ui_pause; return; }
    
    local files=("$EXTERNAL_DIR"/ST_*.tar.gz)
    if [ ! -e "${files[0]}" ]; then ui_print warn "No backup files found."; ui_pause; return; fi

    MENU_ITEMS=()
    for file in "${files[@]}"; do
        local fname=$(basename "$file")
        local fsize=$(du -h "$file" | awk '{print $1}')
        MENU_ITEMS+=("📦 $fname ($fsize)")
    done
    MENU_ITEMS+=("🔙 Back")

    CHOICE=$(ui_menu "Select backup file" "${MENU_ITEMS[@]}")
    if [[ "$CHOICE" == *"Back"* ]]; then return; fi
    
    local selected_name=$(echo "$CHOICE" | awk '{print $2}')
    local selected_file="$EXTERNAL_DIR/$selected_name"

    echo ""
    ui_print warn "Warning: This will overwrite existing chat history and character cards!"
    if ui_confirm "Are you sure you want to continue?"; then
        local TEMP_DIR="$TAVX_DIR/temp_restore"
        local LOCAL_COPY="$TEMP_DIR/restore_target.tar.gz"
        
        safe_rm "$TEMP_DIR"; mkdir -p "$TEMP_DIR"
        
        if ! cp "$selected_file" "$LOCAL_COPY"; then
            ui_print error "Cannot read backup file, please check storage permissions!"
            ui_pause; return
        fi
        
        if ui_spinner "Extracting and verifying..." "tar -xzf '$LOCAL_COPY' -C '$TEMP_DIR'"; then
            cd "$INSTALL_DIR" || return
            
            ui_print info "Importing data..."
            
            if [ -d "$TEMP_DIR/data" ]; then 
                if [ -d "data" ]; then mv data data_old_bak; fi
                
                if cp -r "$TEMP_DIR/data" .; then
                    safe_rm "data_old_bak"
                    ui_print success "Core data (Data) restored successfully"
                else
                    ui_print error "Data restore failed! Rolling back..."
                    safe_rm "data"
                    mv data_old_bak data
                    ui_pause; return
                fi
            fi

            if [ -f "$TEMP_DIR/secrets.json" ]; then 
                cp "$TEMP_DIR/secrets.json" .
                ui_print success "API keys restored"
            fi
            
            if [ -d "$TEMP_DIR/plugins" ]; then
                ui_print info "Restoring server plugins..."
                cp -r "$TEMP_DIR/plugins" .
            fi
            
            if [ -d "$TEMP_DIR/public/scripts/extensions/third-party" ]; then
                ui_print info "Restoring frontend extensions..."
                mkdir -p "public/scripts/extensions/third-party"
                cp -r "$TEMP_DIR/public/scripts/extensions/third-party/." "public/scripts/extensions/third-party/"
            fi
            
            if [ -f "$TEMP_DIR/config.yaml" ]; then 
                 echo ""
                 if ui_confirm "Legacy config file detected in backup, restore it? (Recommended: No)"; then
                    cp "$TEMP_DIR/config.yaml" .
                    ui_print success "Legacy config restored"
                 else
                    ui_print info "Skipped legacy config, keeping current system settings."
                 fi
            fi
            
            safe_rm "$TEMP_DIR"
            echo ""
            ui_print success "🎉 Restore complete! Recommended to restart SillyTavern service."
        else
            ui_print error "Extraction failed! File may be corrupted."
            safe_rm "$TEMP_DIR"
        fi
    else
        ui_print info "Cancelled."
    fi
    ui_pause
}

backup_menu() {
    while true; do
        ui_header "Backup & Restore (Data Only)"
        CHOICE=$(ui_menu "Select function" "📤 Backup Core Data + Plugins" "📥 Restore Data" "🔙 Back to Main Menu")
        case "$CHOICE" in
            *"Backup"*) perform_backup ;;
            *"Restore"*) perform_restore ;;
            *"Back"*) return ;;
        esac
    done
}