#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT 4 — Undo / Restore macOS defaults
# Run as: sudo bash ~/mac-optimised/scripts/4-undo.sh
# Reverts every change made by scripts 1 and 2.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
[ "$(id -u)" != "0" ] && { echo "Re-running with sudo..."; exec sudo bash "$0" "$@"; }

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
log()    { echo -e "  ${GREEN}✓${NC}  $1"; }
warn()   { echo -e "  ${YELLOW}!${NC}  $1"; }
header() { echo -e "\n${BOLD}── $1${NC}"; }

header "Restore UI Defaults"
defaults delete com.apple.dock autohide-time-modifier 2>/dev/null || true
defaults delete com.apple.dock autohide-delay 2>/dev/null || true
defaults delete com.apple.dock expose-animation-duration 2>/dev/null || true
defaults delete com.apple.dock show-recents 2>/dev/null || true
defaults delete NSGlobalDomain NSAutomaticWindowAnimationsEnabled 2>/dev/null || true
defaults delete NSGlobalDomain NSWindowResizeTime 2>/dev/null || true
# universalaccess is locked on macOS 15; restore these manually:
# System Settings → Accessibility → Display → Reduce Motion (off)
# System Settings → Accessibility → Display → Reduce Transparency (off)
warn "Reduce Motion/Transparency: restore manually via System Settings → Accessibility → Display"
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

REAL_USER=$(logname 2>/dev/null || stat -f '%Su' /dev/console)
REAL_UID=$(id -u "$REAL_USER")

header "Re-enable Background Daemons"
UID_NUM=$REAL_UID
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

header "Re-enable Third-Party System Agents"
SYS_AGENTS=(
  "com.adobe.AdobeCreativeCloud"
  "com.adobe.ccxprocess"
  "us.zoom.updater"
  "us.zoom.updater.login.check"
  "com.philandro.anydesk.Frontend"
  "com.microsoft.update.agent"
)
for svc in "${SYS_AGENTS[@]}"; do
  launchctl enable "gui/$REAL_UID/$svc" 2>/dev/null || true
  log "Re-enabled: $svc"
done
SYS_DAEMONS=(
  "com.adobe.ARMDC.Communicator"
  "com.adobe.ARMDC.SMJobBlessHelper"
  "com.adobe.acc.installer.v2"
  "com.philandro.anydesk.Helper"
  "com.philandro.anydesk.service"
)
for svc in "${SYS_DAEMONS[@]}"; do
  launchctl enable "system/$svc" 2>/dev/null || true
  log "Re-enabled: $svc"
done
USER_AGENTS=(
  "com.amazon.codewhisperer.launcher"
  "com.bluejeansnet.BlueJeansHelper"
  "com.bluejeansnet.BlueJeansMenu"
  "com.google.GoogleUpdater.wake"
)
for svc in "${USER_AGENTS[@]}"; do
  launchctl enable "gui/$REAL_UID/$svc" 2>/dev/null || true
  log "Re-enabled: $svc"
done

header "Remove Spotlight Exclusions"
DEV_DIRS=(
  "/Users/$REAL_USER/src" "/Users/$REAL_USER/Developer" "/Users/$REAL_USER/projects"
  "/Users/$REAL_USER/code" "/Users/$REAL_USER/github-repos" "/Users/$REAL_USER/sandbox"
  "/Users/$REAL_USER/Desktop" "/Users/$REAL_USER/Downloads" "/Users/$REAL_USER/opt"
)
for dir in "${DEV_DIRS[@]}"; do
  [ -f "$dir/.metadata_never_index" ] && rm -f "$dir/.metadata_never_index" && log "Spotlight restored: $dir" || true
done

header "Remove LaunchAgents"
# fd limit agent
PLIST="/Users/$REAL_USER/Library/LaunchAgents/com.local.maxfiles.plist"
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST" && log "LaunchAgent removed: com.local.maxfiles" || true
# login agent (runs script 1 on every login)
LOGIN_AGENT="/Users/$REAL_USER/Library/LaunchAgents/com.${REAL_USER}.mac-optimised.plist"
launchctl unload "$LOGIN_AGENT" 2>/dev/null || true
rm -f "$LOGIN_AGENT" && log "Login LaunchAgent removed: com.${REAL_USER}.mac-optimised" || true

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
  sed -i '' '/mac-optimised/,/recvspace/d' /etc/sysctl.conf 2>/dev/null || true
  [ ! -s /etc/sysctl.conf ] && rm -f /etc/sysctl.conf
  log "/etc/sysctl.conf mac-optimised block removed"
fi

header "Restart Services"
killall Dock Finder SystemUIServer cfprefsd 2>/dev/null || true
log "Services restarted"

echo ""
echo -e "${BOLD}Undo complete. Reboot to fully restore kernel/launchd state.${NC}"
