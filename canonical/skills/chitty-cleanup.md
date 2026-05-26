---
name: chitty-cleanup
description: Free disk space on macOS by clearing regenerable caches (npm, pip, brew, Xcode, Docker, etc.). Safe to run anytime — only removes data apps will rebuild.
kind: skill
plugin: chittyos-core
runtimes:
  - claude-code
  - codex
classification:
  - session
  - operations
---

# ChittyOS Mac Cleanup Skill

## Overview
Free disk space by clearing regenerable caches. Safe to run anytime — only removes data that apps will rebuild automatically.

## Usage
```
/cleanup [--dry-run]
```

## Parameters
| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| --dry-run | No | false | Show what would be cleared without deleting |

## Targets

### Browser Caches
| Target | Path | Typical Size |
|--------|------|-------------|
| Chrome | ~/Library/Caches/Google | 1-3GB |
| Chrome (alt) | ~/Library/Caches/com.google.Chrome | 200-500MB |
| Brave | ~/Library/Caches/com.brave.Browser | 200-500MB |
| Firefox | ~/Library/Caches/Firefox | 200-500MB |
| Safari | ~/Library/Caches/com.apple.Safari | 100-300MB |

### App Caches
| Target | Path | Typical Size |
|--------|------|-------------|
| ChatGPT | ~/Library/Caches/com.openai.atlas | 300-600MB |
| Siri TTS | ~/Library/Caches/SiriTTS | 300-500MB |
| Spotify | ~/Library/Caches/com.spotify.client | 100-500MB |
| VS Code | ~/Library/Caches/com.microsoft.VSCode | 100-300MB |

### Dev Tool Caches
| Target | Path | Typical Size |
|--------|------|-------------|
| node-gyp | ~/Library/Caches/node-gyp | 50-200MB |
| pnpm | ~/Library/Caches/pnpm | 50-200MB |
| Homebrew | ~/Library/Caches/Homebrew | 50-200MB |
| TypeScript | ~/Library/Caches/typescript | 10-50MB |
| pip | ~/Library/Caches/pip | 50-200MB |
| yarn | ~/Library/Caches/yarn | 50-200MB |

### System
| Target | Path | Typical Size |
|--------|------|-------------|
| User logs | ~/Library/Logs | 30-100MB |
| Trash | ~/.Trash | Variable |

## Workflow

### Quick Cleanup
```bash
# Run the cleanup script
/Users/nb/Desktop/Projects/github.com/CHITTYOS/chittyserv/scripts/cleanup-mac.sh
```

### Dry Run (check sizes first)
```bash
du -sh ~/Library/Caches/Google ~/Library/Caches/com.openai.atlas ~/Library/Caches/SiriTTS ~/Library/Caches/node-gyp ~/Library/Caches/pnpm ~/Library/Caches/Homebrew ~/Library/Logs ~/.Trash 2>/dev/null | sort -hr
```

### Check Disk Before/After
```bash
df -h /
```

## Safety

### Never Touched
- iCloud / CloudKit data
- Application Support (app state, not cache)
- Docker images
- Downloads folder
- Ubuntu ISO files
- Any user documents

### Always Safe to Clear
Everything listed above is a cache that the owning app will regenerate on next use. No data loss, no re-authentication needed.

## Typical Results
- Expected recovery: 2-5GB per run
- macOS may additionally release purgeable space after cleanup
- Run weekly or whenever disk usage exceeds 90%
