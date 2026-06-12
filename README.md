# macOS Optimised — SRE/DevOps Edition

MacBook: **macOS Sequoia 15.0 · x86_64**  
Optimised: **2026-06-12**

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
│   ├── 1-ui-and-agents.sh         ← UI tweaks + disable background daemons (no sudo, runs on every login via LaunchAgent)
│   ├── 2-sudo-kernel-power.sh     ← kernel limits, power, DNS, caches (sudo, run once + after macOS updates)
│   ├── 3-verify.sh                ← health check — run any time to confirm everything is applied
│   └── 4-undo.sh                  ← full rollback to stock macOS defaults
└── logs/
    └── login-apply.log            ← written on every login by the LaunchAgent (gitignored)
```

---

## Day-to-Day — Nothing to Do

After bootstrap + reboot, everything is automated:

| What | How it auto-loads |
|------|-----------------|
| UI tweaks, daemon kills | LaunchAgent runs `1-ui-and-agents.sh` on every login |
| File descriptor limit 65536 | `~/Library/LaunchAgents/com.local.maxfiles.plist` loads on login |
| `ulimit -n 65536` in every shell | Added to `~/.zshrc` and `~/.bashrc` |
| Kernel sysctl tweaks | `/etc/sysctl.conf` — loaded by kernel on every boot |
| Power management | `pmset` database — permanent until changed |
| Disabled daemons | `launchctl disable` DB — survives every reboot |

---

## After a macOS Update

macOS updates occasionally reset `defaults` preferences and re-enable launchd agents. The login LaunchAgent handles `defaults` automatically. For the kernel/power changes:

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
| Reduce Motion | on | Less GPU load, less distraction |
| Reduce Transparency | on | Eliminates blur compositing (CPU/GPU heavy) |
| Finder animations | off | Snappier file browsing |
| LSQuarantine dialog | **on (default)** | Gatekeeper "downloaded from internet" warning kept — security default |
| DS_Store on network/USB | off | Stops littering remote volumes |
| Finder hidden files | visible | Essential for SRE/DevOps work |
| Finder path + status bar | shown | Instant path context |
| CrashReporter dialog | silenced | No popups interrupting builds |

### Background Daemons — Disabled

| Daemon | What It Does | CPU Impact |
|--------|-------------|------------|
| `photoanalysisd` | On-device ML face/scene detection | **Highest** |
| `photolibraryd` | Photos library background indexing | High |
| `suggestd` | Siri Suggestions — analyses app usage patterns | Medium |
| `knowledgeconstructiond` | Builds Spotlight knowledge graph | Medium |
| `intelligenceflowd` | Apple Intelligence ML pipeline | Medium |
| `inputanalyticsd` | Keystroke pattern logging | Low-Medium |

### Apple Intelligence & Spotlight Knowledge — System Settings Required

These respawn via Mach/XPC regardless of `launchctl disable`. Fix permanently in System Settings:

| Fix | Kills |
|-----|-------|
| System Settings → **Apple Intelligence & Siri** → turn off Apple Intelligence | `intelligenceplatformd`, `intelligencecontextd` |
| System Settings → **Siri & Spotlight** → uncheck all Siri Suggestions | `knowledge-agent`, `spotlightknowledged`, `siriknowledged` |

### File Descriptor Limits

| Limit | macOS Default | After |
|-------|--------------|-------|
| `kern.maxfiles` (system-wide) | 122,880 | **524,288** |
| `kern.maxfilesperproc` (per process) | 61,440 | **524,288** |
| Shell `ulimit -n` | 256 | **65,536** |

### Kernel Sysctl (`/etc/sysctl.conf`)

| Key | Value | Why |
|-----|-------|-----|
| `kern.maxfiles` | 65,536 | Total open file descriptors |
| `kern.maxfilesperproc` | 32,768 | Per-process fd limit |
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

## Verify Everything Is Applied

```bash
bash ~/mac-optimised/scripts/3-verify.sh

# Save a timestamped log
bash ~/mac-optimised/scripts/3-verify.sh | tee ~/mac-optimised/logs/verify-$(date +%Y-%m-%d).txt
```

Expected after running both scripts: 30 checks pass, 3 yellow warnings (System Settings items that need a manual toggle once), 0 failures.

**Note:** `com.apple.universalaccess` (Reduce Motion/Transparency) is TCC-protected on macOS 15 — it cannot be written without sudo. Script 1 handles all no-sudo settings; script 2 (sudo) handles this domain. Run both for a clean verify.

---

## Undo Everything

```bash
sudo bash ~/mac-optimised/scripts/4-undo.sh
sudo reboot
```
