#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT 3 — Verification: checks every optimization is still in place
# Run as: bash ~/mac-optimised/scripts/3-verify.sh
# No sudo needed. Green = good, Red = needs fixing.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0

ok()   { echo -e "  ${GREEN}✓${NC}  $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✗${NC}  $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}!${NC}  $1"; ((WARN++)); }
header() { echo -e "\n${BOLD}── $1${NC}"; }

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
check_sysctl kern.maxfiles        65536
check_sysctl kern.maxfilesperproc 32768

if [ -f /etc/sysctl.conf ] && grep -q 'kern.maxfiles' /etc/sysctl.conf; then
  ok "/etc/sysctl.conf persisted (survives reboot)"
else
  fail "/etc/sysctl.conf missing kern.maxfiles — run script 2 with sudo"
fi

header "3  Background Daemons (should all be GONE)"
DAEMONS=(
  photoanalysisd
  photolibraryd
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
    warn "$proc still running — fix: System Settings (see README)"
  else
    ok "$proc not running"
  fi
done

header "5  Power Management"
HIBERNATE=$(pmset -g | awk '/hibernatemode/{print $2}')
WOMP=$(pmset -g | awk '/womp/{print $2}')
POWERNAP=$(pmset -g | awk '/powernap/{print $2}')

[ "$HIBERNATE" = "0" ] && ok "hibernatemode = 0 (fast sleep/wake)" || fail "hibernatemode = $HIBERNATE (expected 0)"
[ "$WOMP" = "0" ]      && ok "womp = 0 (Wake-on-LAN off)"          || fail "womp = $WOMP (expected 0)"
[ "$POWERNAP" = "0" ]  && ok "powernap = 0"                         || warn "powernap = $POWERNAP (disable in System Settings → Battery)"

header "6  UI Tweaks (defaults)"
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

header "7  LaunchAgent Disabled DB"
UID_NUM=$(id -u)
DISABLED_CHECK=(
  "com.apple.photoanalysisd"
  "com.apple.photolibraryd"
  "com.apple.suggestd"
  "com.apple.knowledge-agent"
  "com.apple.intelligenceplatformd"
)
for svc in "${DISABLED_CHECK[@]}"; do
  state=$(launchctl print-disabled "gui/$UID_NUM" 2>/dev/null | grep "$svc" | grep -o 'disabled\|enabled' || echo "not found")
  [ "$state" = "disabled" ] && ok "$svc => disabled" || fail "$svc => $state (expected disabled)"
done

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}────────────────────────────────────────────────${NC}"
echo -e "  ${GREEN}PASS${NC}  $PASS"
[ $WARN -gt 0 ] && echo -e "  ${YELLOW}WARN${NC}  $WARN (System Settings items — see README)"
[ $FAIL -gt 0 ] && echo -e "  ${RED}FAIL${NC}  $FAIL — re-run script 1 and/or script 2 then reboot"
echo -e "${BOLD}────────────────────────────────────────────────${NC}"
echo ""
[ $FAIL -gt 0 ] && exit 1 || exit 0
