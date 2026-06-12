# macOS Optimised — SRE/DevOps Edition

MacBook: **macOS Sequoia 15.0 · x86_64**  
Optimised: **2026-06-13**

---

## Bootstrap a New Mac

```bash
git clone https://github.com/abdihakim-said/mac-optimised.git ~/mac-optimised
bash ~/mac-optimised/scripts/0-bootstrap.sh
sudo bash ~/mac-optimised/scripts/2-sudo-kernel-power.sh
sudo reboot
```

That's it. Four commands. The bootstrap script installs the login LaunchAgent (so settings re-apply automatically on every future login), runs all UI and daemon tweaks, then tells you exactly what to run next.

---

## Folder Structure

```
~/mac-optimised/
├── README.md
├── scripts/
│   ├── 0-bootstrap.sh             ← run once on a new Mac after git clone
│   ├── 1-ui-and-agents.sh         ← UI tweaks + kill daemons + third-party auto-starters (no sudo, runs on every login)
│   ├── 2-sudo-kernel-power.sh     ← kernel limits, power, system-level agents, Spotlight exclusions (sudo, run once + after macOS updates)
│   ├── 3-verify.sh                ← health check — 9 sections, run any time
│   └── 4-undo.sh                  ← full rollback to stock macOS defaults
└── logs/
    └── login-apply.log            ← written on every login by the LaunchAgent (gitignored)
```

---

## Day-to-Day — Nothing to Do

After bootstrap + reboot, everything is automated:

| What | How it auto-loads |
|------|-----------------|
| UI tweaks, daemon kills, third-party startup suppression | LaunchAgent runs `1-ui-and-agents.sh` on every login |
| File descriptor limit 65536 | `~/Library/LaunchAgents/com.local.maxfiles.plist` loads on login |
| `ulimit -n 65536` in every shell | Added to `~/.zshrc`, `~/.bashrc`, and `~/.bash_profile` |
| Kernel sysctl tweaks | `/etc/sysctl.conf` — loaded by kernel on every boot |
| Power management | `pmset` database — permanent until changed |
| Disabled daemons | `launchctl disable` DB — survives every reboot |

---

## After a macOS Update

macOS updates occasionally reset `defaults` preferences and re-enable launchd agents. The login LaunchAgent handles `defaults` automatically. For the kernel/power/system-level changes:

```bash
sudo bash ~/mac-optimised/scripts/2-sudo-kernel-power.sh
sudo reboot
```

Then verify:

```bash
bash ~/mac-optimised/scripts/3-verify.sh
```

---

## What Was Changed & Why

### UI & Visual Performance

| Setting | Value | Why |
|---------|-------|-----|
| Dock autohide delay | 0 | No pause before Dock appears |
| Dock autohide speed | 0.12s | Near instant |
| Window animations | off | Eliminates GPU compositing on every open/close |
| Mission Control animation | 0.1s | Faster workspace switching |
| Reduce Motion | on | Less GPU load — set manually: System Settings → Accessibility → Display (macOS 15 blocks script access) |
| Reduce Transparency | on | Eliminates blur compositing (CPU/GPU heavy) — set manually: System Settings → Accessibility → Display (macOS 15 blocks script access) |
| Finder animations | off | Snappier file browsing |
| LSQuarantine dialog | **on (default)** | Gatekeeper warning kept — security default |
| DS_Store on network/USB | off | Stops littering remote volumes |
| Finder hidden files | visible | Essential for SRE/DevOps work |
| Finder path + status bar | shown | Instant path context |
| CrashReporter dialog | silenced | No popups interrupting builds |

### Apple Background Daemons — Disabled (script 1)

| Daemon | What It Does | CPU Impact |
|--------|-------------|------------|
| `photoanalysisd` | On-device ML face/scene detection | **Highest** |
| `photolibraryd` | Photos library background indexing | High |
| `suggestd` | Siri Suggestions — analyses app usage | Medium |
| `knowledgeconstructiond` | Builds Spotlight knowledge graph | Medium |
| `intelligenceflowd` | Apple Intelligence ML pipeline | Medium |
| `inputanalyticsd` | Keystroke pattern logging | Low-Medium |

**Note on PhotosReliveWidget:** The Notification Center Photos widget respawns `photoanalysisd`/`photolibraryd` minutes after login. Script 1 kills the widget and does a second-pass kill. To permanently fix: remove the Photos widget from Notification Center.

### Third-Party Auto-Starters — Disabled (scripts 1 + 2)

These apps install themselves as LaunchAgents and run on **every reboot** even when you don't open them:

| App | Impact | Fixed by |
|-----|--------|---------|
| Kiro CLI (CodeWhisperer) | ~10% CPU at idle | script 1 |
| BlueJeans Helper | `KeepAlive: true` — respawns if killed | script 1 |
| BlueJeans Menu | Always in menu bar | script 1 |
| Adobe CCXProcess (user-level) | Creative Cloud background process | script 1 |
| Google Chrome Updater (hourly) | Wakes every 60 min | script 1 |
| Adobe Creative Cloud (system) | Multiple background processes | script 2 |
| Adobe CCXProcess (system) | System-level copy | script 2 |
| Adobe ARMDC Helper (system) | Update/repair daemon | script 2 |
| Zoom updater agents | Login + scheduled update checks | script 2 |
| AnyDesk frontend (system) | Remote desktop, always running | script 2 |
| Legacy login item (Acrobat) | Acrobat Collaboration Synchronizer | script 1 |

Apps still work when launched manually — only the background auto-start is disabled.

### Siri & Spotlight Knowledge — System Settings Required

These respawn via Mach/XPC regardless of `launchctl disable`. Fixed permanently by turning off Siri:

| Fix | Kills |
|-----|-------|
| System Settings → **Siri & Spotlight** → turn off Siri | `knowledge-agent`, `spotlightknowledged`, `siriknowledged`, `suggestd` |

**Note:** Apple Intelligence does not exist on macOS 15.0 — it was introduced in 15.1. No action needed for `intelligenceplatformd`/`intelligencecontextd` on this machine; script 1 kills them on each login and the launchd disable DB prevents auto-start.

### Spotlight — Dev Directories Excluded (script 2)

Spotlight is excluded from indexing these directories to stop `mds_stores` from hammering CPU:

`~/github-repos`, `~/sandbox`, `~/Desktop`, `~/Downloads`, `~/src`, `~/Developer`, `~/projects`, `~/code`, `~/opt`

### File Descriptor Limits

| Limit | macOS Default | After |
|-------|--------------|-------|
| `kern.maxfiles` (system-wide) | 122,880 | **524,288** |
| `kern.maxfilesperproc` (per process) | 61,440 | **524,288** |
| Shell `ulimit -n` | 256 | **65,536** |

### Kernel Sysctl (`/etc/sysctl.conf`)

| Key | Value | Why |
|-----|-------|-----|
| `kern.maxfiles` | 524,288 | Total open file descriptors |
| `kern.maxfilesperproc` | 524,288 | Per-process fd limit |
| `net.inet.tcp.msl` | 15,000 ms | Halves TIME_WAIT — faster port reuse |
| `net.inet.tcp.sendspace` | 262,144 | Larger TCP send buffer |
| `net.inet.tcp.recvspace` | 262,144 | Larger TCP receive buffer |

### Power Management

| Setting | Value | Why |
|---------|-------|-----|
| `hibernatemode` | 0 | No RAM-to-disk on sleep — faster wake |
| `sms` | 0 | Sudden Motion Sensor off — irrelevant on NVMe |
| `womp` | 0 | Wake-on-LAN off |
| `powernap` | 0 | No background activity during sleep |

---

## Known Persistent Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `fileproviderd` high CPU | iCloud Drive syncing after reboot — temporary, clears on its own | Pause iCloud Drive in System Settings → Apple ID if Mac feels slow |

---

## Verify Everything Is Applied

```bash
bash ~/mac-optimised/scripts/3-verify.sh

# Save a timestamped log
bash ~/mac-optimised/scripts/3-verify.sh 2>&1 | tee ~/mac-optimised/logs/verify-$(date +%Y-%m-%d).txt
```

Expected after running both scripts + manual System Settings steps + reboot: **47 pass, 0 warnings**, **0 failures**.

If you see warnings after a fresh reboot:
- `fileproviderd` high CPU — iCloud Drive syncing, clears on its own within ~15 minutes
- `knowledge-agent` / `suggestd` — ensure Siri is off: System Settings → Siri & Spotlight → turn off Siri

---

## Undo Everything

```bash
sudo bash ~/mac-optimised/scripts/4-undo.sh
sudo reboot
```
