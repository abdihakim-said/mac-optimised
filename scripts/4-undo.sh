#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT 4 — Undo / Restore macOS defaults
# Run as: sudo bash ~/mac-optimised/scripts/4-undo.sh
# Reverts every change made by scripts 1 and 2.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
[ "$(id -u)" != "0" ] && { echo "Re-running with sudo..."; exec sudo bash "$0" "$@"; }

GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'
log()    { echo -e "  ${GREEN}✓${NC}  $1"; }
header() { echo -e "\n${BOLD}── $1${NC}"; }

header "Restore UI Defaults"
defaults delete com.apple.dock autohide-time-modifier 2>/dev/null || true
defaults delete com.apple.dock autohide-delay 2>/dev/null || true
defaults delete com.apple.dock expose-animation-duration 2>/dev/null || true
defaults delete com.apple.dock show-recents 2>/dev/null || true
defaults delete NSGlobalDomain NSAutomaticWindowAnimationsEnabled 2>/dev/null || true
defaults delete NSGlobalDomain NSWindowResizeTime 2>/dev/null || true
defaults write com.apple.universalaccess reduceMotion -bool false
defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.LaunchServices LSQuarantine -bool true
log "UI defaults restored to macOS stock"

header "Restore Finder"
defaults delete com.apple.finder DisableAllAnimations 2>/dev/null || true
defaults write com.apple.finder AppleShowAllFiles -bool false
defaults delete com.apple.finder ShowPathbar 2>/dev/null || true
defaults delete com.apple.desktopservices DSDontWriteNetworkStores 2>/dev/null || true
defaults delete com.apple.desktopservices DSDontWriteUSBStores 2>/dev/null || true
log "Finder restored"

header "Restore Analytics"
defaults delete com.apple.CrashReporter DialogType 2>/dev/null || true
log "CrashReporter restored"

header "Re-enable Background Daemons"
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
  launchctl enable "gui/$UID_NUM/$svc" 2>/dev/null || true
  log "Re-enabled: $svc"
done

header "Remove File Descriptor LaunchAgent"
PLIST="$HOME/Library/LaunchAgents/com.local.maxfiles.plist"
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST" && log "LaunchAgent removed: $PLIST"

header "Remove ulimit from Shell Profiles"
for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$RC" ] && sed -i '' '/mac-optimis/d' "$RC" && log "ulimit removed from $RC" || true
done

header "Restore Power Management"
pmset -a hibernatemode 3 && log "Hibernation: restored (mode 3)"
pmset -a sms 1           && log "Sudden Motion Sensor: on"
pmset -a womp 1          && log "Wake-on-LAN: on"
pmset -a powernap 1      && log "Power Nap: on"

header "Remove Sysctl Config"
if [ -f /etc/sysctl.conf ]; then
  sed -i '' '/mac-optimised/,/recvspace/d' /etc/sysctl.conf
  log "/etc/sysctl.conf mac-optimised block removed"
fi

header "Restart Services"
killall Dock Finder SystemUIServer cfprefsd 2>/dev/null || true
log "Services restarted"

echo ""
echo -e "${BOLD}Undo complete. Reboot to fully restore kernel/launchd state.${NC}"
