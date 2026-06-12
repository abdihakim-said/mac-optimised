#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT 2 — Kernel limits, power management, DNS, system-level startup cleanup
# Run as: sudo bash ~/mac-optimised/scripts/2-sudo-kernel-power.sh
# Requires sudo. Safe to re-run.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
[ "$(id -u)" != "0" ] && { echo "Re-running with sudo..."; exec sudo bash "$0" "$@"; }

GREEN='\033[0;32m'; BOLD='\033[1m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()    { echo -e "  ${GREEN}✓${NC}  $1"; }
warn()   { echo -e "  ${YELLOW}!${NC}  $1"; }
header() { echo -e "\n${BOLD}── $1${NC}"; }

# Get the actual logged-in user (not root) for per-user launchctl calls
REAL_USER=$(logname 2>/dev/null || stat -f '%Su' /dev/console)
REAL_UID=$(id -u "$REAL_USER")

header "Accessibility — Reduce Motion & Transparency"
# com.apple.universalaccess is TCC-protected on macOS 15; requires sudo to write
defaults write /Library/Preferences/com.apple.universalaccess reduceMotion       -bool true
defaults write /Library/Preferences/com.apple.universalaccess reduceTransparency -bool true
log "Reduce Motion: on | Reduce Transparency: on (less GPU compositing)"

header "Memory — Purge Inactive RAM"
purge && log "Inactive RAM purged" || warn "purge failed (harmless)"

header "DNS Cache Flush"
dscacheutil -flushcache && killall -HUP mDNSResponder && log "DNS cache flushed"

header "Power Management (SSD-optimised)"
pmset -a hibernatemode 0 && log "Hibernation: off (faster sleep/wake)"
pmset -a sms 0           && log "Sudden Motion Sensor: off (SSD doesn't need it)"
pmset -a womp 0          && log "Wake-on-LAN: off"
pmset -a powernap 0      && log "Power Nap: off"
rm -f /private/var/vm/sleepimage 2>/dev/null && log "Stale hibernation image removed" || true

header "System Caches (rebuilt automatically)"
rm -rf /Library/Caches/* 2>/dev/null && log "System /Library/Caches cleared" || warn "Some system caches couldn't clear (non-fatal)"

header "Spotlight — Stop Indexing Dev Directories"
DEV_DIRS=(
  "/Users/$REAL_USER/src"
  "/Users/$REAL_USER/Developer"
  "/Users/$REAL_USER/projects"
  "/Users/$REAL_USER/code"
  "/Users/$REAL_USER/github-repos"
  "/Users/$REAL_USER/sandbox"
  "/Users/$REAL_USER/Desktop"
  "/Users/$REAL_USER/Downloads"
  "/Users/$REAL_USER/opt"
)
for dir in "${DEV_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    mdutil -i off "$dir" 2>/dev/null && log "Spotlight off: $dir" || warn "mdutil failed: $dir"
  fi
done

header "Disable Third-Party System LaunchAgents (/Library/LaunchAgents)"
# These run for every user session — disable them in the user's gui session
SYS_AGENTS=(
  "com.adobe.AdobeCreativeCloud"
  "com.adobe.ccxprocess"
  "us.zoom.updater"
  "us.zoom.updater.login.check"
  "com.philandro.anydesk.Frontend"
  "com.microsoft.update.agent"
)
for svc in "${SYS_AGENTS[@]}"; do
  launchctl disable "gui/$REAL_UID/$svc" 2>/dev/null || true
  launchctl bootout  "gui/$REAL_UID/$svc" 2>/dev/null || true
  log "Disabled system agent: $svc"
done

# Adobe ARMDCHelper uses a long hash in its label — match by glob
ADOBE_ARMDC_PLIST=$(ls /Library/LaunchAgents/com.adobe.ARMDCHelper.*.plist 2>/dev/null | head -1)
if [ -n "$ADOBE_ARMDC_PLIST" ]; then
  ARMDC_LABEL=$(defaults read "$ADOBE_ARMDC_PLIST" Label 2>/dev/null || true)
  [ -n "$ARMDC_LABEL" ] && launchctl disable "gui/$REAL_UID/$ARMDC_LABEL" 2>/dev/null || true
  [ -n "$ARMDC_LABEL" ] && launchctl bootout  "gui/$REAL_UID/$ARMDC_LABEL" 2>/dev/null || true
  log "Disabled: Adobe ARMDCHelper"
fi

header "Disable Third-Party System LaunchDaemons (/Library/LaunchDaemons)"
# These run as root — disable at the system level
SYS_DAEMONS=(
  "com.adobe.ARMDC.Communicator"
  "com.adobe.ARMDC.SMJobBlessHelper"
  "com.adobe.acc.installer.v2"
  "com.philandro.anydesk.Helper"
  "com.philandro.anydesk.service"
)
for svc in "${SYS_DAEMONS[@]}"; do
  launchctl disable "system/$svc" 2>/dev/null || true
  launchctl bootout  "system/$svc" 2>/dev/null || true
  log "Disabled system daemon: $svc"
done

# Kill running third-party processes that were just unloaded
killall -9 "Adobe Creative Cloud" AdobeCreativeCloud CCXProcess AdobeResourceSynchronizer \
            AnyDesk anydesk 2>/dev/null || true
log "Killed remaining third-party processes"

header "Sysctl Kernel Tweaks"
# Write to /etc/sysctl.conf — loaded by kernel on every boot
# Always overwrite — ensures values are correct even if run again after a fix
cat > /etc/sysctl.conf <<'EOF'
# mac-optimised — SRE/DevOps kernel tuning
# macOS Sequoia defaults: kern.maxfiles=122880, kern.maxfilesperproc=61440
# Raised well above defaults for container/service workloads
kern.maxfiles=524288
kern.maxfilesperproc=524288
net.inet.tcp.msl=15000
net.inet.tcp.sendspace=262144
net.inet.tcp.recvspace=262144
EOF
log "Sysctl params written to /etc/sysctl.conf (active on next reboot)"

# Apply live where macOS allows it
sysctl -w kern.maxfiles=524288        2>/dev/null && log "kern.maxfiles=524288 (live)"        || true
sysctl -w kern.maxfilesperproc=524288 2>/dev/null && log "kern.maxfilesperproc=524288 (live)" || true

echo ""
echo -e "${BOLD}Script 2 complete.${NC} Reboot to apply all kernel/launchd changes."
