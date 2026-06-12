# macOS Optimised — SRE/DevOps Edition

MacBook: **macOS Sequoia 15.0 · x86_64**  
Optimised: **2026-06-12**

---

## Folder Structure

```
~/mac-optimised/
├── README.md                      ← this file
├── scripts/
│   ├── 1-ui-and-agents.sh         ← UI tweaks + disable background daemons (no sudo)
│   ├── 2-sudo-kernel-power.sh     ← Kernel limits, power, DNS, caches (sudo)
│   ├── 3-verify.sh                ← Check every setting is still in place
│   └── 4-undo.sh                  ← Revert everything back to macOS defaults
└── logs/                          ← Drop verify output here for records
```

---

## How to Run (fresh machine or after OS update)

```bash
# Step 1 — UI, agents, file descriptor LaunchAgent
bash ~/mac-optimised/scripts/1-ui-and-agents.sh

# Step 2 — Kernel, power management, DNS, caches (needs sudo)
sudo bash ~/mac-optimised/scripts/2-sudo-kernel-power.sh

# Step 3 — Verify everything applied correctly
bash ~/mac-optimised/scripts/3-verify.sh

# Reboot once to activate sysctl + launchd changes
sudo reboot
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
| LSQuarantine dialog | off | No "are you sure?" popup on dev tools |
| DS_Store on network/USB | off | Stops littering remote volumes |
| Finder hidden files | visible | Essential for SRE/DevOps work |
| Finder path + status bar | shown | Instant path context |
| CrashReporter dialog | silenced | No popups interrupting builds |

**How it persists:** Written to `~/Library/Preferences/` plist files. Loaded every session automatically. Survives reboot indefinitely.

---

### Background Daemons — Disabled

These were the biggest background CPU consumers. All disabled via `launchctl disable` (written to macOS's system disabled-db) and stopped via `launchctl bootout`.

| Daemon | What It Does | CPU Impact |
|--------|-------------|------------|
| `photoanalysisd` | On-device ML face/scene detection — runs constantly scanning Photos library | **Highest** |
| `photolibraryd` | Photos library background indexing | High |
| `suggestd` | Siri Suggestions — analyses app usage patterns | Medium |
| `knowledgeconstructiond` | Builds knowledge graph for Spotlight | Medium |
| `intelligenceflowd` | Apple Intelligence ML pipeline | Medium |
| `inputanalyticsd` | Logs every keystroke pattern for "analytics" | Low-Medium |

**How it persists:** `launchctl disable` writes to `/var/db/com.apple.xpc.launchd/` — survives reboot. Does not reset on macOS update (usually).

---

### Apple Intelligence & Spotlight Knowledge — Partial (System Settings Required)

These 5 daemons respawn via Mach/XPC ports — another system process calls them on-demand, so `launchctl disable` alone can't fully stop them.

| Daemon | Trigger | Fix |
|--------|---------|-----|
| `intelligenceplatformd` | Apple Intelligence enabled | System Settings → Apple Intelligence & Siri → **turn off Apple Intelligence** |
| `intelligencecontextd` | Apple Intelligence enabled | Same as above |
| `knowledge-agent` | Spotlight Suggestions enabled | System Settings → Siri & Spotlight → **uncheck all Siri Suggestions** |
| `spotlightknowledged` | Spotlight Suggestions enabled | Same as above |
| `siriknowledged` | Siri enabled | Same as above |

**Status:** Both `intelligenceplatformd` and `knowledge-agent` chains were disabled in the launchd database. The 2 System Settings toggles above are the final step to prevent XPC re-activation.

---

### File Descriptor Limits (Critical for SRE/DevOps)

Running many containers, services, and file watchers will hit macOS's default limit of 256 open files fast. We raised it:

| Limit | Before | After |
|-------|--------|-------|
| Soft (per shell) | 256 | 65,536 |
| Hard (kernel max) | 524,288 | 65,536 soft / 200,000 hard |

**How it persists — two layers:**
1. `~/Library/LaunchAgents/com.local.maxfiles.plist` — sets the limit via `launchctl limit` on every login
2. `ulimit -n 65536` added to `~/.zshrc` and `~/.bashrc` — every terminal session inherits it

---

### Kernel Sysctl Tweaks (`/etc/sysctl.conf`)

Loaded by the kernel on every boot. Active on next reboot after run.

| Key | Value | Why |
|-----|-------|-----|
| `kern.maxfiles` | 65,536 | Total open file descriptors across all processes |
| `kern.maxfilesperproc` | 32,768 | Per-process limit |
| `net.inet.tcp.msl` | 15,000 ms | Halves TIME_WAIT from 30s → 15s (faster port reuse for local services) |
| `net.inet.tcp.sendspace` | 262,144 | Larger TCP send buffer (faster local service throughput) |
| `net.inet.tcp.recvspace` | 262,144 | Larger TCP receive buffer |

**File:** `/etc/sysctl.conf`

---

### Power Management

| Setting | Value | Why |
|---------|-------|-----|
| `hibernatemode` | 0 | Disables writing RAM to disk on sleep — faster sleep/wake, frees disk space equal to your RAM size |
| `sms` (Sudden Motion Sensor) | 0 | Irrelevant on NVMe/SSD — one less background sensor daemon |
| `womp` (Wake-on-LAN) | 0 | Stops unexpected wakes from Bonjour/network |
| `powernap` | 0 | Prevents background activity during sleep |

**How it persists:** `pmset` writes to the system power management database. Survives reboot permanently until manually changed.

---

### DNS Cache

Flushed at time of optimisation. Not a persistent change — macOS rebuilds the cache as you browse. Re-run script 2 any time you hit DNS weirdness.

---

## Verifying Everything Is Still Applied

Run this any time — after an update, after a reboot, or just to check:

```bash
bash ~/mac-optimised/scripts/3-verify.sh
```

Expected output: all green ticks except the 5 System Settings items (shown as yellow warnings, not failures).

To save a log:
```bash
bash ~/mac-optimised/scripts/3-verify.sh | tee ~/mac-optimised/logs/verify-$(date +%Y-%m-%d).txt
```

---

## After a macOS Update

macOS updates can reset some `defaults` and occasionally re-enable launchd agents. After any update:

```bash
bash ~/mac-optimised/scripts/1-ui-and-agents.sh
sudo bash ~/mac-optimised/scripts/2-sudo-kernel-power.sh
bash ~/mac-optimised/scripts/3-verify.sh
sudo reboot
```

---

## Undoing Everything

```bash
sudo bash ~/mac-optimised/scripts/4-undo.sh
sudo reboot
```

---

## What Does NOT Need Re-Running After Reboot

Everything below is permanently stored and loads automatically:

- `~/Library/LaunchAgents/com.local.maxfiles.plist` — loads on login
- `~/.zshrc` ulimit — loads on every terminal session
- `/etc/sysctl.conf` — loaded by kernel on boot
- `pmset` settings — stored in power management DB
- `launchctl disable` entries — stored in `/var/db/com.apple.xpc.launchd/`
- `defaults write` entries — stored in `~/Library/Preferences/`

**You never need to run these scripts again unless:**
- macOS update resets something (run verify to check)
- You want to add new optimisations
- You want to undo changes
