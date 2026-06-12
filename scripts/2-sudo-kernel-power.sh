#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT 2 — Kernel limits, power management, DNS, caches
# Run as: sudo bash ~/mac-optimised/scripts/2-sudo-kernel-power.sh
# Requires sudo. Safe to re-run.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
[ "$(id -u)" != "0" ] && { echo "Re-running with sudo..."; exec sudo bash "$0" "$@"; }

GREEN='\033[0;32m'; BOLD='\033[1m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "  ${GREEN}✓${NC}  $1"; }
warn() { echo -e "  ${YELLOW}!${NC}  $1"; }
header() { echo -e "\n${BOLD}── $1${NC}"; }

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
for dir in "/Users/$(logname)/src" "/Users/$(logname)/Developer" "/Users/$(logname)/projects" "/Users/$(logname)/code"; do
  [ -d "$dir" ] && mdutil -i off "$dir" 2>/dev/null && log "Spotlight off: $dir" || true
done

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
