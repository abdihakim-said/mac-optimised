#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT 1 — UI tweaks + disable background CPU hogs + third-party auto-starters
# Run as: bash ~/mac-optimised/scripts/1-ui-and-agents.sh
# Safe to re-run. No sudo required.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
log()    { echo -e "  ${GREEN}✓${NC}  $1"; }
warn()   { echo -e "  ${YELLOW}!${NC}  $1"; }
header() { echo -e "\n${BOLD}── $1${NC}"; }

header "UI — Animations & Transparency"
defaults write com.apple.dock autohide-time-modifier -float 0.12
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.dock show-recents -bool false
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
defaults write NSGlobalDomain com.apple.springing.enabled -bool true
defaults write NSGlobalDomain com.apple.springing-delay -float 0.1
defaults write com.apple.LaunchServices LSQuarantine -bool true
log "Dock instant | window animations off | Gatekeeper kept on"
warn "reduceMotion/reduceTransparency require sudo — run script 2 (TCC-protected on macOS 15)"

header "Finder"
defaults write com.apple.finder DisableAllAnimations -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
log "Animations off | hidden files visible | DS_Store suppressed"

header "Analytics & Crash Reporting"
defaults write com.apple.CrashReporter DialogType none
defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false 2>/dev/null || true
defaults write com.apple.assistant.support "Siri Data Sharing Opt-In Status" -int 2 2>/dev/null || true
log "CrashReporter silenced | DiagnosticInfo off | Siri data sharing off"

header "Legacy Login Items"
# Remove any leftover login items from apps that self-register
osascript -e 'tell application "System Events" to delete every login item whose name is "Acrobat Collaboration Synchronizer"' 2>/dev/null && log "Removed: Acrobat Collaboration Synchronizer login item" || true
osascript -e 'tell application "System Events" to delete every login item whose name is "BlueJeans"' 2>/dev/null || true
osascript -e 'tell application "System Events" to delete every login item whose name is "AnyDesk"' 2>/dev/null || true

header "Disable Apple Background CPU Hog Daemons"
UID_NUM=$(id -u)
AGENTS=(
  "com.apple.photoanalysisd"
  "com.apple.photolibraryd"
  "com.apple.intelligenceplatformd"
  "com.apple.intelligencecontextd"
  "com.apple.intelligenceflowd"
  "com.apple.knowledge-agent"
  "com.apple.suggestd"
  "com.apple.knowledgeconstructiond"
  "com.apple.spotlightknowledged"
  "com.apple.siriknowledged"
  "com.apple.inputanalyticsd"
)
for svc in "${AGENTS[@]}"; do
  launchctl disable "gui/$UID_NUM/$svc" 2>/dev/null
  launchctl bootout "gui/$UID_NUM/$svc" 2>/dev/null || true
  # bootout removes the job from launchd tracking but does NOT kill a running process
  proc_name="${svc##*.}"
  killall -9 "$proc_name" 2>/dev/null || true
  log "Disabled + stopped: $svc"
done

# PhotosReliveWidget (Notification Center widget) respawns photo daemons minutes after login
# Kill the widget first, then do a second-pass kill on the daemons
# Permanent fix: remove the Photos widget from Notification Center
killall -9 PhotosReliveWidget 2>/dev/null && log "Killed PhotosReliveWidget (prevents photo daemon respawn)" || true
sleep 1
killall -9 photoanalysisd photolibraryd 2>/dev/null || true

header "Disable Third-Party Auto-Starters (user-level)"
# These install themselves as LaunchAgents and run on every login consuming CPU/RAM
# Apps still work fine when launched manually — only the background auto-start is disabled

THIRD_PARTY_AGENTS=(
  "com.amazon.codewhisperer.launcher"   # Kiro CLI — ~10% CPU at idle
  "com.bluejeansnet.BlueJeansHelper"    # KeepAlive:true — respawns itself if killed!
  "com.bluejeansnet.BlueJeansMenu"      # BlueJeans menu bar
  "com.adobe.ccxprocess"                # Adobe CCXProcess (user-level copy)
  "com.google.GoogleUpdater.wake"       # Chrome updater wake — runs every hour
)
for svc in "${THIRD_PARTY_AGENTS[@]}"; do
  launchctl disable "gui/$UID_NUM/$svc" 2>/dev/null || true
  launchctl bootout "gui/$UID_NUM/$svc" 2>/dev/null || true
  log "Disabled: $svc"
done

# Kill by actual binary names (different from service label for some apps)
killall -9 kiro_cli_desktop 2>/dev/null || true       # Kiro / CodeWhisperer
killall -9 BlueJeansHelper  2>/dev/null || true
killall -9 BlueJeansMenu    2>/dev/null || true
killall -9 CCXProcess       2>/dev/null || true        # Adobe Creative Cloud Experience
killall -9 GoogleUpdater    2>/dev/null || true
log "Killed: Kiro CLI, BlueJeans, Adobe CCXProcess, Google Updater"

header "File Descriptor Limit (LaunchAgent)"
LIMIT_PLIST="$HOME/Library/LaunchAgents/com.local.maxfiles.plist"
if [ ! -f "$LIMIT_PLIST" ]; then
  cat > "$LIMIT_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>          <string>com.local.maxfiles</string>
  <key>ProgramArguments</key>
  <array>
    <string>launchctl</string><string>limit</string>
    <string>maxfiles</string>
    <string>65536</string><string>200000</string>
  </array>
  <key>RunAtLoad</key>      <true/>
</dict>
</plist>
EOF
  launchctl load "$LIMIT_PLIST" 2>/dev/null || true
  log "LaunchAgent installed: fd limit 65536/200000 on every boot"
else
  log "LaunchAgent already exists — skipping"
fi

header "Shell Profile — ulimit"
ULIMIT_LINE='ulimit -n 65536  # mac-optimised'
for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -f "$RC" ] && ! grep -q 'mac-optimised' "$RC" 2>/dev/null; then
    echo "$ULIMIT_LINE" >> "$RC"
    log "ulimit added to $RC"
  elif [ -f "$RC" ]; then
    log "ulimit already in $RC — skipping"
  fi
done

header "Restart Affected Services"
killall Dock SystemUIServer Finder cfprefsd 2>/dev/null || true
log "Dock, Finder, SystemUIServer, cfprefsd restarted"

echo ""
echo -e "${BOLD}Script 1 complete.${NC} Run script 2 next (needs sudo)."
