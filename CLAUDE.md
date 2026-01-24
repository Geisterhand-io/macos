# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Geisterhand is a macOS screen automation tool that provides both an HTTP API and CLI for controlling mouse, keyboard, and capturing screenshots. It requires macOS Accessibility and Screen Recording permissions.

## Build Commands

```bash
# Build all targets
swift build

# Build for release
swift build -c release

# Run the CLI tool
swift run geisterhand

# Run the menu bar app
swift run GeisterhandApp

# Run tests
swift test

# Run a single test
swift test --filter "keyCodeMapLetters"
```

## Architecture

The project has three main targets:

### GeisterhandCore (Library)
The shared core functionality used by both the CLI and the app:
- **Server/HTTPServer.swift**: Hummingbird-based HTTP server (`GeisterhandServer` actor) running on port 7676 by default. `ServerManager` provides a synchronous wrapper for app lifecycle management.
- **Server/Routes/**: Individual route handlers for each endpoint (`/status`, `/screenshot`, `/click`, `/type`, `/key`, `/scroll`)
- **Input/KeyboardController.swift**: CGEvent-based keyboard automation. Uses `KeyCodeMap` for key name to keycode translation.
- **Input/MouseController.swift**: CGEvent-based mouse automation (clicks, scrolling)
- **Screen/ScreenCaptureService.swift**: ScreenCaptureKit-based screen capture (actor)
- **Permissions/PermissionManager.swift**: Checks and requests Accessibility (`AXIsProcessTrusted`) and Screen Recording permissions
- **Models/APIModels.swift**: Codable request/response types for the HTTP API

### GeisterhandApp (Menu Bar App)
SwiftUI menu bar application that:
- Lives in the system menu bar with a hand icon
- Shows permission and server status via icon color (green/yellow/red)
- Manages server lifecycle through `AppDelegate`
- Uses `StatusMonitor` for periodic status updates

### geisterhand (CLI)
ArgumentParser-based CLI with subcommands: `screenshot`, `click`, `type`, `key`, `scroll`, `status`, `server`

## HTTP API Endpoints

All endpoints run on `127.0.0.1:7676`:
- `GET /status` - System info and permission status
- `GET /screenshot` - Capture screen (returns base64 PNG)
- `POST /click` - Click at coordinates
- `POST /type` - Type text
- `POST /key` - Press key with modifiers
- `POST /scroll` - Scroll at position

## Key Patterns

- Core services use singletons (`.shared`) for shared state
- `ScreenCaptureService` and `GeisterhandServer` are actors for thread safety
- Tests use Swift Testing framework (`@Test`, `#expect`)
- JSON uses snake_case encoding/decoding strategy
