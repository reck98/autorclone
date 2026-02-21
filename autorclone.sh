#!/bin/bash
set -e

# ---------- ENV ----------
APP_DIR="$HOME/.autorclone"
mkdir -p "$APP_DIR"

# ---------- COLOR THEME ----------
ACCENT="\033[38;5;99m"      # Indigo
GREEN="\033[38;5;82m"       # Soft green
RED="\033[38;5;196m"        # Soft red
YELLOW="\033[38;5;214m"     # Amber
CYAN="\033[38;5;51m"        # Cyan
GRAY="\033[38;5;244m"
NC="\033[0m"

accent()  { echo -e "${ACCENT}$1${NC}"; }
info()    { echo -e "${CYAN}➜ $1${NC}"; }
success() { echo -e "${GREEN}✔ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $1${NC}"; }
error()   { echo -e "${RED}✖ $1${NC}"; exit 1; }

pause() { sleep 0.6; }

# ---------- UI ----------
section() {
  echo ""
  accent "──────────────── $1 ────────────────"
}

welcome() {
clear
echo -e "${ACCENT}"
cat <<EOF
╭────────────────────────────────────────╮
│      🚀 AutoRclone GDrive Installer    │
│                                        │
│  Secure • Automated • Self-Healing     │
╰────────────────────────────────────────╯
EOF
echo -e "${NC}"
}

title() {
  echo ""
  accent "━━━━━━━━━━ $1 ━━━━━━━━━━"
}

done_msg() {
  echo -e "${GREEN}✔ $1${NC}"
}

# ---------- DISTRO ----------
detect_distro() {
  title "System Detection"

  # Only use gum spinner if it's already installed
  if command -v gum >/dev/null 2>&1; then
      gum spin --spinner dot --title "Detecting Linux distribution..." -- sleep 1
  else
      info "Detecting Linux distribution..."
      sleep 1
  fi

  source /etc/os-release || error "Cannot detect OS"
  DISTRO=$ID

  success "Detected distro: $DISTRO"
  pause
}

# ---------- PACKAGE INSTALL ----------
install_pkg() {
case "$DISTRO" in
  ubuntu|debian) sudo apt update && sudo apt install -y "$1" ;;
  fedora) sudo dnf install -y "$1" ;;
  arch|manjaro) sudo pacman -Sy --noconfirm "$1" ;;
  opensuse*) sudo zypper install -y "$1" ;;
  *) error "Unsupported distro" ;;
esac
}

check_and_install() {
  PKG=$1

  if command -v "$PKG" >/dev/null 2>&1; then
      success "$PKG found"
  else
      # If gum exists, use the spinner. If not (like when installing gum itself), just run it.
      if command -v gum >/dev/null 2>&1; then
          gum spin --spinner dot --title "Installing $PKG..." -- install_pkg "$PKG"
      else
          info "Installing $PKG (please wait)..."
          install_pkg "$PKG" >/dev/null 2>&1
      fi
      success "$PKG installed"
  fi
  pause
}

# ---------- DEPENDENCIES ----------
check_dependencies() {
section "Dependency Check"

check_and_install curl
check_and_install rclone
check_and_install gum
}



select_profile_name() {
title "🧾 Backup Profile Name"

while true; do
    PROFILE=$(gum input --placeholder "e.g. college, work, photos")

    if [ -z "$PROFILE" ]; then
        warn "Profile name cannot be empty"
        continue
    fi

    if [[ ! "$PROFILE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        warn "Use only letters, numbers, dash (-) and underscore (_)"
        continue
    fi

    if [ -f "$HOME/.autorclone/${PROFILE}.env" ]; then
        warn "Profile '$PROFILE' already exists"
        warn "Choose a different name"
        continue
    fi

    success "Profile name accepted: $PROFILE"
    pause
    break
done
}

view_profile() {
    title "👁  View Profile Settings"
    
    shopt -s nullglob
    local envs=("$HOME/.autorclone/"*.env)
    if [ ${#envs[@]} -eq 0 ]; then
        warn "No profiles found."
        pause
        return
    fi
    
    local PROFILES=()
    for f in "${envs[@]}"; do
        PROFILES+=("$(basename "$f" .env)")
    done

    PROFILE=$(gum choose --header "Select profile to view:" "${PROFILES[@]}")
    [ -z "$PROFILE" ] && return

    (
        source "$HOME/.autorclone/${PROFILE}.env"
        
        echo ""
        accent "╭── Profile: $PROFILE ───"
        echo -e "${CYAN}Local Folder     :${NC} $LOCAL_PATH"
        echo -e "${CYAN}Drive Remote     :${NC} $REMOTE_NAME"
        echo -e "${CYAN}Remote Folder    :${NC} $REMOTE_PATH"
        echo -e "${CYAN}Sync Mode        :${NC} $SYNC_MODE"
        echo -e "${CYAN}Backup Interval  :${NC} $INTERVAL"
        echo -e "${CYAN}Telegram Enabled :${NC} $TELEGRAM_ENABLED"
        
        if [ "$TELEGRAM_ENABLED" = "true" ]; then
            MASKED_TOKEN="${BOT_TOKEN:0:8}••••••••••••••••"
            echo -e "${CYAN}Bot Token        :${NC} $MASKED_TOKEN"
            echo -e "${CYAN}Chat ID          :${NC} $CHAT_ID"
        fi
        accent "╰─────────────────────────"
        echo ""
    )

    echo -e "${GRAY}Press ENTER to return to the main menu...${NC}"
    read -r
}

update_profile() {
    title "✏  Update Profile"
    
    shopt -s nullglob
    local envs=("$HOME/.autorclone/"*.env)
    if [ ${#envs[@]} -eq 0 ]; then
        warn "No profiles found."
        pause
        return
    fi
    
    local PROFILES=""
    for f in "${envs[@]}"; do
        PROFILES+="$(basename "$f" .env)\n"
    done

    PROFILE=$(echo -e "$PROFILES" | gum choose --header "Select profile to update:")
    [ -z "$PROFILE" ] && return

    source "$HOME/.autorclone/${PROFILE}.env"
    GDRIVE_REMOTE="$REMOTE_NAME"

    while true; do
        STATUS_TG="Toggle Telegram (Currently: $TELEGRAM_ENABLED)"

        UPDATE_CHOICE=$(gum choose \
            "Change Backup Interval" \
            "Change Sync Mode" \
            "$STATUS_TG" \
            "Update Telegram Bot Token" \
            "💾 Save & Apply Updates" \
            "❌ Cancel")

        case "$UPDATE_CHOICE" in
            "Change Backup Interval") select_interval ;;
            "Change Sync Mode") select_sync_mode ;;
            "$STATUS_TG")
                if [ "$TELEGRAM_ENABLED" = "true" ]; then
                    TELEGRAM_ENABLED="false"
                    success "Telegram notifications disabled."
                else
                    TELEGRAM_ENABLED="true"
                    success "Telegram notifications enabled."
                    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
                        warn "No credentials found. Running setup..."
                        setup_telegram_credentials
                    fi
                fi
                pause
                ;;
            "Update Telegram Bot Token") setup_telegram_credentials ;;
            "💾 Save & Apply Updates") break ;;
            "❌ Cancel")
                info "Updates cancelled. No changes were made."
                pause
                return
                ;;
        esac
    done

    info "Applying updates..."
    write_config
    generate_backup_script
    create_systemd_units

    success "Profile '$PROFILE' updated successfully!"
    pause
}

delete_profile() {
  title "🗑  Delete Profile"
  
  # Safely check for profiles without triggering set -e
  shopt -s nullglob
  local envs=("$HOME/.autorclone/"*.env)
  if [ ${#envs[@]} -eq 0 ]; then
      warn "No profiles found."
      pause
      return
  fi
  
  local PROFILES=""
  for f in "${envs[@]}"; do
      PROFILES+="$(basename "$f" .env)\n"
  done

  PROFILE_TO_DELETE=$(echo -e "$PROFILES" | gum choose --header "Select profile to delete:")
  [ -z "$PROFILE_TO_DELETE" ] && return

  gum confirm "Are you sure you want to delete profile '$PROFILE_TO_DELETE'?" || return

  info "Stopping systemd timer..."
  # Use || true so the script doesn't crash if the timer is already dead
  systemctl --user disable --now "autorclone-${PROFILE_TO_DELETE}.timer" 2>/dev/null || true
  rm -f "$HOME/.config/systemd/user/autorclone-${PROFILE_TO_DELETE}."{service,timer}
  systemctl --user daemon-reload

  info "Removing scripts and configuration..."
  rm -f "$HOME/.autorclone/${PROFILE_TO_DELETE}.env"
  rm -f "$HOME/.autorclone/backup_${PROFILE_TO_DELETE}.sh"

  success "Profile '$PROFILE_TO_DELETE' completely removed."
  pause
}

# ---------- GDRIVE REMOTE SETUP ----------
setup_gdrive_remote() {
section "Google Drive Setup"

gum spin --spinner dot --title "Checking rclone configuration..." -- sleep 1

REMOTES=$(rclone listremotes 2>/dev/null || true)

if [ -n "$REMOTES" ]; then
    success "Google Drive remotes found:"
    echo "$REMOTES" | sed 's/^/  - /'

    echo ""
    info "Choose Google Drive remote"

    OPTIONS=()
    while read -r r; do OPTIONS+=("$r"); done <<< "$REMOTES"
    OPTIONS+=("Create new Google Drive remote")

    CHOICE=$(gum choose --cursor.foreground="105" --selected.foreground="82" "${OPTIONS[@]}")

    if [ "$CHOICE" != "Create new Google Drive remote" ]; then
        GDRIVE_REMOTE="${CHOICE%:}"
        success "Using remote: $GDRIVE_REMOTE"
        pause
        return
    fi
fi

warn "You will now configure Google Drive"
info "When asked:"
info "  - Choose: n (New remote)"
info "  - Name: Enter any name (example: gdrive)"
info "  - Storage: drive"
info "  - Keep defaults unless you know otherwise"
info "  - Browser will open for Google login"
info "  - After done, type q to exit"
echo ""

gum confirm "Launch rclone config now?" || error "Setup cancelled"

rclone config

REMOTES=$(rclone listremotes 2>/dev/null || true)
if [ -z "$REMOTES" ]; then
    error "No Google Drive remote found after setup"
fi

GDRIVE_REMOTE=$(echo "$REMOTES" | tail -n 1 | sed 's/://')
success "Google Drive remote created: $GDRIVE_REMOTE"
pause
}

view_remotes() {
    title "☁  View Google Drive Remotes"
    
    REMOTES=$(rclone listremotes 2>/dev/null || true)
    
    if [ -z "$REMOTES" ]; then
        warn "No remotes configured in rclone."
    else
        echo -e "${CYAN}Configured Remotes:${NC}"
        echo "$REMOTES" | sed 's/^/  - /'
    fi
    
    echo ""
    echo -e "${GRAY}Press ENTER to return to the main menu...${NC}"
    read -r
}

delete_remote() {
    title "🔥 Delete Google Drive Remote"
    
    REMOTES=$(rclone listremotes 2>/dev/null || true)
    
    if [ -z "$REMOTES" ]; then
        warn "No remotes available to delete."
        pause
        return
    fi
    
    local OPTIONS=()
    while read -r r; do OPTIONS+=("${r%:}"); done <<< "$REMOTES"
    
    REMOTE_TO_DELETE=$(gum choose --header "Select remote to delete:" "${OPTIONS[@]}")
    [ -z "$REMOTE_TO_DELETE" ] && return

    local linked_profiles=()
    shopt -s nullglob
    for f in "$HOME/.autorclone/"*.env; do
        # Fixed: Catch grep exit code so set -e doesn't crash the script
        local r_name=$(grep -E "^REMOTE_NAME=" "$f" 2>/dev/null | cut -d'"' -f2 || true)
        if [ "$r_name" = "$REMOTE_TO_DELETE" ]; then
            linked_profiles+=("$(basename "$f" .env)")
        fi
    done

    echo ""
    warn "DANGER ZONE: You are about to delete the remote '$REMOTE_TO_DELETE'."
    
    if [ ${#linked_profiles[@]} -gt 0 ]; then
        warn "This will ALSO delete the following active backup profiles:"
        for p in "${linked_profiles[@]}"; do echo -e "  ${RED}✖ $p${NC}"; done
    else
        info "No active profiles are using this remote."
    fi
    
    echo ""
    gum confirm --selected.background="196" "Are you ABSOLUTELY sure you want to delete '$REMOTE_TO_DELETE'?" || return
    
    for p in "${linked_profiles[@]}"; do
        info "Stopping and removing profile: $p..."
        systemctl --user disable --now "autorclone-${p}.timer" 2>/dev/null || true
        rm -f "$HOME/.config/systemd/user/autorclone-${p}."{service,timer}
        rm -f "$HOME/.autorclone/${p}.env"
        rm -f "$HOME/.autorclone/backup_${p}.sh"
    done
    systemctl --user daemon-reload

    info "Deleting remote '$REMOTE_TO_DELETE' from rclone config..."
    rclone config delete "$REMOTE_TO_DELETE"

    success "Remote '$REMOTE_TO_DELETE' and all associated profiles have been deleted."
    pause
}

# ---------- FOLDER & SYNC CONFIG ----------
select_local_folder() {
title "📁 Local Folder Selection"

DEFAULTS=("$HOME/Documents" "$HOME/Desktop" "$HOME/Downloads" "Enter custom path")

while true; do
    PICK=$(gum choose --cursor.foreground="105" --selected.foreground="82" "${DEFAULTS[@]}")

    if [ "$PICK" = "Enter custom path" ]; then
        echo ""
        LOCAL_PATH=$(gum input --placeholder "/home/user/your-folder")
    else
        LOCAL_PATH="$PICK"
    fi

    if [ -z "$LOCAL_PATH" ]; then
        warn "Path cannot be empty"
        continue
    fi

    # Fixed: Prevent .env injection attacks
    if [[ "$LOCAL_PATH" == *\"* ]] || [[ "$LOCAL_PATH" == *\$* ]] || [[ "$LOCAL_PATH" == *\`* ]]; then
        warn "Path cannot contain quotes, dollar signs, or backticks"
        continue
    fi

    if [ "$LOCAL_PATH" = "/" ] || [ "$LOCAL_PATH" = "$HOME" ]; then
        warn "Cannot use root or full HOME directory"
        continue
    fi

    if [ ! -d "$LOCAL_PATH" ]; then
        warn "Folder does not exist."
        ACTION=$(gum choose "Create this folder" "Enter different path")
        if [ "$ACTION" = "Create this folder" ]; then
            if mkdir -p "$LOCAL_PATH"; then
                success "Folder created: $LOCAL_PATH"
            else
                warn "Failed to create folder. Try again."
                continue
            fi
        else
            continue
        fi
    fi

    LOCAL_PATH=$(realpath "$LOCAL_PATH")
    done_msg "Selected local folder: $LOCAL_PATH"
    pause
    break
done
}

select_remote_folder() {
title "☁ Google Drive Folder"

while true; do
    REMOTE_PATH=$(gum input --placeholder "Backups/MyFolder")

    if [ -z "$REMOTE_PATH" ]; then
        warn "Remote folder cannot be empty"
        continue
    fi

    # Fixed: Prevent .env injection attacks
    if [[ "$REMOTE_PATH" == *\"* ]] || [[ "$REMOTE_PATH" == *\$* ]] || [[ "$REMOTE_PATH" == *\`* ]]; then
        warn "Path cannot contain quotes, dollar signs, or backticks"
        continue
    fi

    # Fixed: Safely pass variables to sh -c to prevent command injection
    if gum spin --spinner dot --title "Checking remote folder..." -- \
        sh -c 'rclone lsf "$1" >/dev/null 2>&1' _ "$GDRIVE_REMOTE:$REMOTE_PATH"
    then
        success "Remote folder exists: $REMOTE_PATH"
        pause
        break
    else
        warn "Remote folder does not exist"
        ACTION=$(gum choose "Create this folder" "Enter different path")

        if [ "$ACTION" = "Create this folder" ]; then
            # Fixed: Safely pass variables to sh -c
            if gum spin --spinner dot --title "Creating remote folder..." -- \
                sh -c 'rclone mkdir "$1"' _ "$GDRIVE_REMOTE:$REMOTE_PATH"
            then
                success "Remote folder created: $REMOTE_PATH"
                pause
                break
            else
                warn "Failed to create remote folder"
            fi
        fi
    fi
done
}

validate_paths() {
if [ "$SYNC_MODE" = "local_to_drive" ] || [ "$SYNC_MODE" = "drive_to_local" ]; then
    if [ "$LOCAL_PATH" = "$GDRIVE_REMOTE:$REMOTE_PATH" ]; then
        error "Source and destination cannot be the same"
    fi
fi
}

select_interval() {
title "⏱ Backup Interval"

INTERVAL_LABEL=$(gum choose \
  "Every 5 minutes" "Every 15 minutes" "Every 30 minutes" \
  "Every 1 hour" "Every 2 hours" "Every 4 hours" \
  "Every 8 hours" "Every 12 hours" "Every 24 hours")

case "$INTERVAL_LABEL" in
  "Every 5 minutes") INTERVAL="5m" ;;
  "Every 15 minutes") INTERVAL="15m" ;;
  "Every 30 minutes") INTERVAL="30m" ;;
  "Every 1 hour") INTERVAL="1h" ;;
  "Every 2 hours") INTERVAL="2h" ;;
  "Every 4 hours") INTERVAL="4h" ;;
  "Every 8 hours") INTERVAL="8h" ;;
  "Every 12 hours") INTERVAL="12h" ;;
  "Every 24 hours") INTERVAL="24h" ;;  
esac

success "Interval selected: $INTERVAL"
pause
}

select_sync_mode() {
title "🔁 Sync Mode"

SYNC_CHOICE=$(gum choose \
  "Two-way Sync (Local ⇄ Drive)" \
  "One-way Sync (Local → Drive)" \
  "One-way Sync (Drive → Local)")

case "$SYNC_CHOICE" in
  "Two-way Sync (Local ⇄ Drive)") SYNC_MODE="bisync"; success "Selected: Two-way Sync" ;;
  "One-way Sync (Local → Drive)") SYNC_MODE="local_to_drive"; success "Selected: Local → Drive" ;;
  "One-way Sync (Drive → Local)") SYNC_MODE="drive_to_local"; success "Selected: Drive → Local" ;;
esac
pause
}

dry_run_test() {
title "🧪 Verification"

if [ "$SYNC_MODE" = "bisync" ]; then
    CMD=(rclone bisync "$LOCAL_PATH" "$GDRIVE_REMOTE:$REMOTE_PATH" --dry-run --resync)
elif [ "$SYNC_MODE" = "local_to_drive" ]; then
    CMD=(rclone sync "$LOCAL_PATH" "$GDRIVE_REMOTE:$REMOTE_PATH" --dry-run)
else
    CMD=(rclone sync "$GDRIVE_REMOTE:$REMOTE_PATH" "$LOCAL_PATH" --dry-run)
fi

# Fixed: Removed bash -c to prevent array flattening and passed directly to gum, also caught exit code for set -e
if gum spin --spinner dot --title "Running dry-run test..." -- "${CMD[@]}"; then
    done_msg "Dry-run successful"
else
    error "Dry-run failed. Please verify paths and remote."
fi
}

# ---------- TELEGRAM SETUP ----------
setup_telegram_credentials() {
    echo ""
    info "How to get Telegram Bot Token:"
    info "  1) Open Telegram"
    info "  2) Search: @BotFather"
    info "  3) Send: /start"
    info "  4) Send: /newbot"
    info "  5) Choose a name and username"
    info "  6) Copy the token given"
    echo ""

    while true; do
        BOT_TOKEN=$(gum input --placeholder "Paste Telegram Bot Token")
        [ -z "$BOT_TOKEN" ] && warn "Bot token cannot be empty" && continue
        break
    done

    # Fixed: Safely pass variables to sh -c
    while true; do

        echo ""
        info "Now you must start your bot:"
        info "  1) Open Telegram"
        info "  2) Search your bot username"
        info "  3) Send: /start"
        echo ""

        CONFIRM=$(gum choose "Yes, I have sent /start" "No, I will do it now")
        if [ "$CONFIRM" = "No, I will do it now" ]; then
            warn "Please send /start to your bot, then confirm."
            continue
        fi

        # Fixed: Passed variable safely as $1 to prevent command injection, and caught exit code to prevent set -e crash
        if gum spin --spinner dot --title "Verifying Telegram connection..." -- sh -c '
            for i in $(seq 1 30); do
                RESP=$(curl -s "https://api.telegram.org/bot$1/getUpdates")
                CHAT_ID=$(echo "$RESP" | grep -o "\"chat\":{\"id\":[0-9-]*" | head -n1 | grep -o "[0-9-]*")
                if [ -n "$CHAT_ID" ]; then
                    echo "$CHAT_ID" > /tmp/autorclone_chatid
                    exit 0
                fi
                sleep 2
            done
            exit 1
        ' _ "$BOT_TOKEN"; then
            CHAT_ID=$(cat /tmp/autorclone_chatid)
            TELEGRAM_ENABLED="true"
            success "Telegram connected successfully!"
            success "Chat ID detected: $CHAT_ID"
            
            # --- NEW: Send verification message to the bot ---
            info "Sending test message to your bot..."
            curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
                 -d chat_id="$CHAT_ID" \
                 -d text="✅ AutoRclone: Telegram connection verified successfully! You will receive backup reports here." >/dev/null
            # -------------------------------------------------

            pause
            break
        else
            warn "Could not detect /start message."
            warn "Make sure you sent /start to your bot."
        fi
    done
}

setup_telegram() {
    title "📨 Telegram Setup"

    CHOICE=$(gum choose "Enable Telegram notifications" "Skip Telegram setup")

    if [ "$CHOICE" = "Skip Telegram setup" ]; then
        TELEGRAM_ENABLED="false"
        BOT_TOKEN=""
        CHAT_ID=""
        success "Telegram disabled"
        pause
        return
    fi

    setup_telegram_credentials
}

# ---------- SYSTEM GENERATION ----------
write_config() {
CONFIG="$HOME/.autorclone/${PROFILE}.env"

cat > "$CONFIG" <<EOF
LOCAL_PATH="$LOCAL_PATH"
REMOTE_PATH="$REMOTE_PATH"
REMOTE_NAME="$GDRIVE_REMOTE"
SYNC_MODE="$SYNC_MODE"
INTERVAL="$INTERVAL"

TELEGRAM_ENABLED="$TELEGRAM_ENABLED"
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
EOF

chmod 600 "$CONFIG"
success "Config saved"
pause
}

generate_backup_script() {
SCRIPT="$HOME/.autorclone/backup_${PROFILE}.sh"

cat > "$SCRIPT" <<EOF
#!/bin/bash
source "$HOME/.autorclone/${PROFILE}.env"

# Directories
LOG_DIR="\$HOME/.autorclone/.autorclone_logs/\${PROFILE}"
# FIXED: Isolate the queue directory per profile to prevent cross-contamination
QUEUE_DIR="\$LOG_DIR/telegram_queue"
mkdir -p "\$LOG_DIR" "\$QUEUE_DIR"

# File Paths
LOG_FILE="\$LOG_DIR/backup_\$(date +%Y-%m-%d_%H-%M-%S).log"
SYNCED_LOG="\$LOCAL_PATH/AutoRclone_Backup_Log.txt"
TMP="/tmp/rclone_changes_\${PROFILE}.txt"
RCLONE_FULL="/tmp/rclone_full_\${PROFILE}.txt"

# -------- LOG HEADER --------
echo "===== BACKUP RUN =====" >> "\$LOG_FILE"
START_TIME=\$(date '+%Y-%m-%d %H:%M:%S')
START_TS=\$(date +%s)
echo "Start : \$START_TIME" >> "\$LOG_FILE"
echo "Mode  : \$SYNC_MODE" >> "\$LOG_FILE"

# -------- COMMAND SELECTION --------
if [ "\$SYNC_MODE" = "bisync" ]; then
  CMD=(rclone bisync "\$LOCAL_PATH" "\$REMOTE_NAME:\$REMOTE_PATH")
elif [ "\$SYNC_MODE" = "local_to_drive" ]; then
  CMD=(rclone sync "\$LOCAL_PATH" "\$REMOTE_NAME:\$REMOTE_PATH")
else
  CMD=(rclone sync "\$REMOTE_NAME:\$REMOTE_PATH" "\$LOCAL_PATH")
fi

# -------- RUN RCLONE --------
"\${CMD[@]}" --log-level INFO --stats-one-line 2>&1 | \\
    sed 's/\x1b\[[0-9;]*m//g' | \\
    tee "\$RCLONE_FULL" | \\
    grep -iE "copied|moved|deleted|updated|file changed|error|failed|critical" > "\$TMP"
    
RCLONE_STATUS=\${PIPESTATUS[0]}

END_TS=\$(date +%s)
DURATION=\$((END_TS - START_TS))

# -------- EXTRACT TRANSFERRED SIZE --------
TRANSFERRED=\$(grep -o "Transferred:.*" "\$RCLONE_FULL" | tail -1 | cut -d',' -f1)
[ -z "\$TRANSFERRED" ] && TRANSFERRED="Transferred: 0 B"

# -------- WRITE LOG --------
if [ -s "\$TMP" ]; then
   sed 's/^/ - /' "\$TMP" >> "\$LOG_FILE"
else
   echo " - No file changes" >> "\$LOG_FILE"
fi

if [ \$RCLONE_STATUS -eq 0 ]; then
   STATUS="SUCCESS"
else
   STATUS="FAILED"
fi

echo "Status: \$STATUS" >> "\$LOG_FILE"
echo "Duration: \${DURATION}s" >> "\$LOG_FILE"
echo "\$TRANSFERRED" >> "\$LOG_FILE"
echo "End   : \$(date '+%Y-%m-%d %H:%M:%S')" >> "\$LOG_FILE"
echo "" >> "\$LOG_FILE"

# Copy latest log into synced folder safely
if [ -d "\$LOCAL_PATH" ]; then
    cp "\$LOG_FILE" "\$SYNCED_LOG" 2>/dev/null || true
fi

# -------- TELEGRAM MESSAGE (UX) --------
if [ "\$TELEGRAM_ENABLED" = "true" ]; then

    if [ "\$STATUS" = "SUCCESS" ]; then
        STATUS_ICON="✅ SUCCESS"
    else
        STATUS_ICON="❌ FAILED"
    fi

    if [ -s "\$TMP" ]; then
        CHANGE_COUNT=\$(wc -l < "\$TMP")
        # Truncate to avoid Telegram limits for massive syncs
        CHANGE_LIST=\$(head -n 20 "\$TMP" | sed 's/^/   • /')
        if [ "\$CHANGE_COUNT" -gt 20 ]; then
            CHANGE_LIST="\$CHANGE_LIST\n   ... and \$((\$CHANGE_COUNT - 20)) more changes"
        fi
    else
        CHANGE_COUNT=0
        CHANGE_LIST="   • No file changes"
    fi

    MSG="🗂 *Backup Report*

📂 Profile: ${PROFILE}
⏰ Time: \$START_TIME
🚦 Status: *\$STATUS_ICON*

📊 Changes: \$CHANGE_COUNT
\$CHANGE_LIST

⏱ Duration: \${DURATION}s
📦 \$TRANSFERRED"

    # 1. Save Text Message to Queue
    MSG_FILE="\$QUEUE_DIR/msg_\$(date +%s).txt"
    echo -e "\$MSG" > "\$MSG_FILE"

    # 2. Save Document Path to Queue (ONLY IF FAILED)
    if [ "\$STATUS" = "FAILED" ]; then
        DOC_FILE="\$QUEUE_DIR/doc_\$(date +%s).txt"
        echo "\$LOG_FILE" > "\$DOC_FILE"
    fi

    # -------- SEND / QUEUE LOGIC --------
    if curl -s --head https://api.telegram.org >/dev/null; then
        
        # Send queued text messages
        for f in "\$QUEUE_DIR"/msg_*.txt; do
            [ -e "\$f" ] || continue
            curl -s -X POST "https://api.telegram.org/bot\$BOT_TOKEN/sendMessage" \\
                 -d chat_id="\$CHAT_ID" \\
                 -d parse_mode="Markdown" \\
                 -d text="\$(cat "\$f")" \\
                 > /dev/null 2>&1 && rm -f "\$f"
        done

        # Send queued log documents
        for f in "\$QUEUE_DIR"/doc_*.txt; do
            [ -e "\$f" ] || continue
            DOC_PATH=\$(cat "\$f")
            
            if [ -f "\$DOC_PATH" ]; then
                curl -s -X POST "https://api.telegram.org/bot\$BOT_TOKEN/sendDocument" \\
                     -F chat_id="\$CHAT_ID" \\
                     -F document=@"\$DOC_PATH" \\
                     > /dev/null 2>&1 && rm -f "\$f"
            else
                rm -f "\$f"
            fi
        done
    fi
fi
EOF

chmod +x "$SCRIPT"
success "Backup script created"
pause
}

create_systemd_units() {
SERVICE="$HOME/.config/systemd/user/autorclone-${PROFILE}.service"
TIMER="$HOME/.config/systemd/user/autorclone-${PROFILE}.timer"

mkdir -p "$HOME/.config/systemd/user"

cat > "$SERVICE" <<EOF
[Unit]
Description=AutoRclone Backup

[Service]
Type=oneshot
ExecStart=$HOME/.autorclone/backup_${PROFILE}.sh
EOF

cat > "$TIMER" <<EOF
[Unit]
Description=AutoRclone Timer

[Timer]
OnBootSec=1m
OnUnitActiveSec=$INTERVAL
Persistent=true
Unit=autorclone-${PROFILE}.service

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload

systemctl --user disable --now "autorclone-${PROFILE}.timer" 2>/dev/null || true
systemctl --user enable --now "autorclone-${PROFILE}.timer" 2>/dev/null || true
systemctl --user start "autorclone-${PROFILE}.timer" 2>/dev/null || true

systemctl --user start "autorclone-${PROFILE}.service" 2>/dev/null || true



success "systemd timer enabled"
pause
}

# ---------- MENU ROUTERS ----------
create_new_profile() {
  select_profile_name
  success "Environment ready 🎉"

  info "Starting Google Drive Setup"
  setup_gdrive_remote
  success "Google Drive remote setup complete 🎉"

  info "Configuring folders and interval"
  select_local_folder
  select_remote_folder
  select_sync_mode
  validate_paths
  select_interval
  dry_run_test

  title "📋 Configuration Summary"
  echo -e "${CYAN}Local Folder :${NC} $LOCAL_PATH"
  echo -e "${CYAN}Drive Folder :${NC} $REMOTE_PATH"
  echo -e "${CYAN}Sync Mode    :${NC} $SYNC_MODE"
  echo -e "${CYAN}Interval     :${NC} $INTERVAL"
  echo ""
  success "Folders and interval configured 🎉"

  info "Next: Telegram setup & automation"
  setup_telegram
  write_config
  generate_backup_script
  create_systemd_units

  section "Installation Complete"
  success "AutoRclone is now running automatically 🎉"
  info "Backups will run every $INTERVAL"
  pause
}

main_menu() {
  clear
  welcome
  while true; do
    
    CHOICE=$(gum choose \
      "✨ Create New Profile" \
      "👁  View Profile Settings" \
      "✏  Update Profile" \
      "🗑  Delete Profile" \
      "☁  View Remotes" \
      "🔥 Delete Remote" \
      "🚪 Exit")

    case "$CHOICE" in
      "✨ Create New Profile") create_new_profile ;;
      "👁  View Profile Settings") view_profile ;;
      "✏  Update Profile") update_profile ;;
      "🗑  Delete Profile") delete_profile ;;
      "☁  View Remotes") view_remotes ;;
      "🔥 Delete Remote") delete_remote ;;
      "🚪 Exit") 
          success "Exiting AutoRclone. Goodbye!"
          exit 0 
          ;;
    esac
  done
}

# ---------- BOOTSTRAP EXECUTION ----------
welcome
detect_distro
check_dependencies
main_menu
