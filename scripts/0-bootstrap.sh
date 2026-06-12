#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT 0 — Bootstrap: run once on a fresh Mac after cloning the repo.
#
# Usage (from any location):
#   bash ~/mac-optimised/scripts/0-bootstrap.sh
#
# What it does:
#   1. Installs the login LaunchAgent (auto-applies settings on every login)
#   2. Runs script 1 immediately (UI, daemons, fd limits)
#   3. Prints instructions for the sudo step + reboot
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

GREEN='\033[0;32m'; BOLD='\033[1m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()    { echo -e "  ${GREEN}✓${NC}  $1"; }
warn()   { echo -e "  ${YELLOW}!${NC}  $1"; }
header() { echo -e "\n${BOLD}── $1${NC}"; }

# Resolve the repo root from wherever this script lives
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT1="$REPO_DIR/scripts/1-ui-and-agents.sh"
SCRIPT2="$REPO_DIR/scripts/2-sudo-kernel-power.sh"
AGENT_LABEL="com.$(whoami).mac-optimised"
AGENT_PLIST="$HOME/Library/LaunchAgents/${AGENT_LABEL}.plist"

echo -e "\n${BOLD}macOS Bootstrap — SRE/DevOps Edition${NC}"
echo "  Repo: $REPO_DIR"
echo "  User: $(whoami)  |  $(sw_vers -productName) $(sw_vers -productVersion)"
echo ""

# ── 1. Install login LaunchAgent ──────────────────────────────────────────────
header "Installing Login LaunchAgent"

mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$REPO_DIR/logs"

cat > "$AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${AGENT_LABEL}</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${SCRIPT1}</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>StandardOutPath</key>
  <string>${REPO_DIR}/logs/login-apply.log</string>
  <key>StandardErrorPath</key>
  <string>${REPO_DIR}/logs/login-apply.log</string>

  <key>KeepAlive</key>
  <false/>
</dict>
</plist>
EOF

launchctl unload "$AGENT_PLIST" 2>/dev/null || true
launchctl load   "$AGENT_PLIST" 2>/dev/null && log "LaunchAgent installed + loaded: $AGENT_PLIST" || warn "LaunchAgent load failed — check path"

# ── 2. Run script 1 now ───────────────────────────────────────────────────────
header "Running Script 1 (UI, daemons, fd limits)"
bash "$SCRIPT1"

# ── 3. Instructions for sudo step ────────────────────────────────────────────
echo ""
echo -e "${BOLD}────────────────────────────────────────────────${NC}"
echo -e "${BOLD}Bootstrap complete. Two more steps:${NC}"
echo ""
echo "  STEP A — run with sudo (kernel limits, power, DNS, caches):"
echo "    sudo bash $SCRIPT2"
echo ""
echo "  STEP B — reboot:"
echo "    sudo reboot"
echo -e "${BOLD}────────────────────────────────────────────────${NC}"
echo ""
