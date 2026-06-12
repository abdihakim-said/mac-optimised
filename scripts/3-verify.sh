#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT 3 — Verification: checks every optimization is still in place
# Run as: bash ~/mac-optimised/scripts/3-verify.sh
# No sudo needed. Green = good, Yellow = warning, Red = needs fixing.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0

ok()   { echo -e "  ${GREEN}✓${NC}  $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✗${NC}  $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}!${NC}  $1"; ((WARN++)); }
header() { echo -e "\n${BOLD}── $1${NC}"; }

UID_NUM=$(id -u)

# ─── 1. File Descriptor Limit ────────────────────────────────────────────────
header "1  File Descriptor Limit"
FD=$(ulimit -n)
if [ "$FD" -ge 65536 ] 2>/dev/null; then
  ok "ulimit -n = $FD (>= 65536)"
else
  fail "ulimit -n = $FD — too low (expected >= 65536)"
fi

PLIST="$HOME/Library/LaunchAgents/com.local.maxfiles.plist"
[ -f "$PLIST" ] && ok "LaunchAgent plist exists: $PLIST" || fail "LaunchAgent missing: $PLIST"

if grep -q 'mac-optimised\|mac-optimize' "$HOME/.zshrc" 2>/dev/null; then
  ok "ulimit in ~/.zshrc"
else
  fail "ulimit NOT in ~/.zshrc — new shells won't get raised limits"
fi

# ─── 2. Sysctl Kernel Values ─────────────────────────────────────────────────
header "2  Sysctl Kernel Values"
check_sysctl() {
  local key=$1 expected=$2
  local val
  val=$(sysctl -n "$key" 2>/dev/null)
  if [ "$val" -ge "$expected" ] 2>/dev/null; then
    ok "$key = $val"
  else
    fail "$key = $val (expected >= $expected) — run script 2 and reboot"
  fi
}
check_sysctl kern.maxfiles        524288
check_sysctl kern.maxfilesperproc 524288

if [ -f /etc/sysctl.conf ] && grep -q 'kern.maxfiles' /etc/sysctl.conf; then
  ok "/etc/sysctl.conf persisted (survives reboot)"
else
  fail "/etc/sysctl.conf missing kern.maxfiles — run script 2 with sudo"
fi

# ─── 3. Apple Background Daemons ─────────────────────────────────────────────
header "3  Apple Background Daemons (should all be GONE)"
DAEMONS=(
  knowledgeconstructiond
  intelligenceflowd
  inputanalyticsd
)
for proc in "${DAEMONS[@]}"; do
  if pgrep -x "$proc" > /dev/null 2>&1; then
    fail "$proc is running — re-run script 1"
  else
    ok "$proc not running"
  fi
done

# Photos daemons: respawned by PhotosReliveWidget (Notification Center widget)
for proc in photoanalysisd photolibraryd; do
  if pgrep -x "$proc" > /dev/null 2>&1; then
    if pgrep -x "PhotosReliveWidget" > /dev/null 2>&1; then
      warn "$proc running — caused by PhotosReliveWidget; remove Photos widget from Notification Center to permanently fix"
    else
      fail "$proc is running — re-run script 1"
    fi
  else
    ok "$proc not running"
  fi
done

# ─── 4. Apple Intelligence & Spotlight Knowledge (System Settings required) ──
header "4  Apple Intelligence & Spotlight Knowledge (System Settings required)"
SIPS_DAEMONS=(
  intelligenceplatformd
  intelligencecontextd
  knowledge-agent
  spotlightknowledged
  siriknowledged
  suggestd
)
for proc in "${SIPS_DAEMONS[@]}"; do
  if pgrep -x "$proc" > /dev/null 2>&1; then
    warn "$proc still running — fix: System Settings → Apple Intelligence & Siri (see README)"
  else
    ok "$proc not running"
  fi
done

# ─── 5. Third-Party Auto-Starters ────────────────────────────────────────────
header "5  Third-Party Auto-Starters (should not be running at login)"
check_not_running() {
  local label=$1 proc=$2
  # Use -x for exact process name match to avoid false positives from command-line args
  if pgrep -x "$proc" > /dev/null 2>&1; then
    fail "$label is running at startup — re-run script 1 (user-level) or script 2 (system-level)"
  else
    ok "$label not auto-starting"
  fi
}

check_not_running "Kiro CLI / CodeWhisperer"  "kiro_cli_desktop"
check_not_running "BlueJeansHelper"           "BlueJeansHelper"
check_not_running "BlueJeansMenu"             "BlueJeansMenu"
check_not_running "Adobe CCXProcess"          "CCXProcess"
check_not_running "Adobe Creative Cloud"      "AdobeCreativeCloud"
check_not_running "AnyDesk"                   "AnyDesk"

# Zoom daemons — warn rather than fail (Zoom is often needed for meetings)
if pgrep -x "ZoomDaemon" > /dev/null 2>&1; then
  warn "ZoomDaemon is running — disable Zoom system daemon via script 2 if not needed"
fi

# ─── 6. Power Management ─────────────────────────────────────────────────────
header "6  Power Management"
HIBERNATE=$(pmset -g | awk '/hibernatemode/{print $2}')
WOMP=$(pmset -g | awk '/womp/{print $2}')
POWERNAP=$(pmset -g | awk '/powernap/{print $2}')

[ "$HIBERNATE" = "0" ] && ok "hibernatemode = 0 (fast sleep/wake)" || fail "hibernatemode = $HIBERNATE (expected 0)"
[ "$WOMP" = "0" ]      && ok "womp = 0 (Wake-on-LAN off)"          || fail "womp = $WOMP (expected 0)"
[ "$POWERNAP" = "0" ]  && ok "powernap = 0"                         || warn "powernap = $POWERNAP — disable: System Settings → Battery"

# ─── 7. UI Tweaks (defaults) ─────────────────────────────────────────────────
header "7  UI Tweaks (defaults)"
check_default() {
  local domain=$1 key=$2 expected=$3 label=$4
  local val
  val=$(defaults read "$domain" "$key" 2>/dev/null)
  if [ "$val" = "$expected" ]; then
    ok "$label"
  else
    fail "$label — got '$val', expected '$expected' — re-run script 1"
  fi
}
check_default com.apple.dock           autohide-time-modifier "0.12"  "Dock instant autohide"
check_default com.apple.dock           show-recents           "0"     "Dock recent apps hidden"
check_default com.apple.finder         DisableAllAnimations   "1"     "Finder animations off"
check_default com.apple.finder         AppleShowAllFiles      "1"     "Hidden files visible"
check_default com.apple.CrashReporter  DialogType             "none"  "CrashReporter silenced"
check_default NSGlobalDomain           NSWindowResizeTime     "0.001" "Window resize instant"

# universalaccess is fully locked on macOS 15 — even root cannot write it.
# These must be toggled manually in System Settings → Accessibility → Display.
check_system_ua() {
  local key=$1 label=$2
  # Try both user domain and system domain reads
  local val
  val=$(defaults read com.apple.universalaccess "$key" 2>/dev/null || \
        defaults read /Library/Preferences/com.apple.universalaccess "$key" 2>/dev/null || \
        echo "0")
  if [ "$val" = "1" ]; then
    ok "$label"
  else
    warn "$label — set manually: System Settings → Accessibility → Display"
  fi
}
check_system_ua reduceMotion       "Reduce Motion on (less GPU load)"
check_system_ua reduceTransparency "Reduce Transparency on (no blur compositing)"

# ─── 8. LaunchAgent Disabled DB ──────────────────────────────────────────────
header "8  LaunchAgent Disabled DB"
DISABLED_CHECK=(
  "com.apple.photoanalysisd"
  "com.apple.photolibraryd"
  "com.apple.suggestd"
  "com.apple.knowledge-agent"
  "com.apple.intelligenceplatformd"
  "com.amazon.codewhisperer.launcher"
  "com.bluejeansnet.BlueJeansHelper"
  "com.bluejeansnet.BlueJeansMenu"
  "com.adobe.ccxprocess"
  "com.google.GoogleUpdater.wake"
)
for svc in "${DISABLED_CHECK[@]}"; do
  state=$(launchctl print-disabled "gui/$UID_NUM" 2>/dev/null | grep "$svc" | grep -o 'disabled\|enabled' || echo "not found")
  if [ "$state" = "disabled" ]; then
    ok "$svc => disabled"
  elif [ "$state" = "not found" ]; then
    warn "$svc => not in launchd DB (run script 1 to register)"
  else
    fail "$svc => $state (expected disabled — re-run script 1)"
  fi
done

# ─── 9. High-CPU Process Warnings ────────────────────────────────────────────
header "9  High-CPU Process Warnings"
# fileproviderd = iCloud Drive syncing; high CPU means active sync or stuck
FILEPROV_CPU=$(ps aux | awk '/fileproviderd/ && !/awk/ {printf "%.0f", $3}' | head -1)
if [ -n "$FILEPROV_CPU" ] && [ "$FILEPROV_CPU" -gt 20 ] 2>/dev/null; then
  warn "fileproviderd CPU = ${FILEPROV_CPU}% — iCloud Drive is syncing heavily; consider pausing iCloud Drive in System Settings if Mac feels slow"
else
  ok "fileproviderd CPU normal (${FILEPROV_CPU:-0}%)"
fi

# mds_stores = Spotlight indexing; high CPU = still building index
MDS_CPU=$(ps aux | awk '/mds_stores/ && !/awk/ {printf "%.0f", $3}' | head -1)
if [ -n "$MDS_CPU" ] && [ "$MDS_CPU" -gt 10 ] 2>/dev/null; then
  warn "mds_stores CPU = ${MDS_CPU}% — Spotlight indexing; run script 2 to exclude dev directories"
else
  ok "mds_stores CPU normal (${MDS_CPU:-0}%)"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}────────────────────────────────────────────────${NC}"
echo -e "  ${GREEN}PASS${NC}  $PASS"
[ $WARN -gt 0 ] && echo -e "  ${YELLOW}WARN${NC}  $WARN"
[ $FAIL -gt 0 ] && echo -e "  ${RED}FAIL${NC}  $FAIL — re-run script 1 and/or script 2 (sudo) then reboot"
[ $FAIL -eq 0 ] && [ $WARN -eq 0 ] && echo -e "  ${GREEN}All clear.${NC}"
echo -e "${BOLD}────────────────────────────────────────────────${NC}"
echo ""
[ $FAIL -gt 0 ] && exit 1 || exit 0
