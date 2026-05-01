# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`claude-bar` is a minimal macOS menu bar app (NSStatusItem) that displays Claude Code usage stats — session quota, weekly quota, and time-to-reset — directly in the system status bar alongside Bluetooth, language, and other menu bar icons.

Target display format: `19→89 [5d]` where `19` is current usage %, `89` is projected usage %, and `5d` is time until reset.

## Data Sources

The app reads the same files as `~/.claude/usage-statusline.sh`:

- `~/.claude/usage-cache.json` — session/weekly quota percentages and reset timestamps (written by a separate fetch script)
- `~/.claude/settings.json` — effort level
- `~/.claude/projects/<project-key>/*.jsonl` — per-session token usage for context % calculation

## Build & Run

```bash
# Open in Xcode
open claude-bar.xcodeproj

# Build from CLI
xcodebuild -scheme claude-bar -configuration Debug build

# Run tests
xcodebuild -scheme claude-bar -configuration Debug test
```

## Architecture

Single-target Swift app, no storyboard, entry point via `@main` on `AppDelegate`.

- **AppDelegate** — creates `NSStatusItem`, owns the menu bar icon and title label; starts the refresh timer
- **UsageReader** — reads and parses `usage-cache.json`, `settings.json`; returns a `UsageSnapshot` value type
- **StatusFormatter** — pure function: `UsageSnapshot → String`; produces the compact status string shown in the menu bar
- **RefreshTimer** — wraps a `Timer` that calls `UsageReader` + `StatusFormatter` every 30 s and on wake-from-sleep

No UI beyond the status item title. No popover or menu required for the initial version.

## Key Conventions

- Minimum deployment target: macOS 13
- No third-party dependencies — Foundation + AppKit only
- All file I/O is synchronous and happens off the main thread (use `DispatchQueue.global()`)
- `UsageSnapshot` is a `struct` with all optional fields; missing data degrades gracefully (show `--` instead of crashing)
