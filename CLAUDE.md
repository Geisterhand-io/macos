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
- **Server/Routes/**: Individual route handlers for each endpoint (`/status`, `/screenshot`, `/click`, `/click/element`, `/type`, `/key`, `/scroll`, `/wait`, `/accessibility/*`, `/menu`)
- **Input/KeyboardController.swift**: CGEvent-based keyboard automation. Uses `KeyCodeMap` for key name to keycode translation. Supports PID-targeted key events via `pressKey(key:modifiers:targetPid:)`.
- **Input/MouseController.swift**: CGEvent-based mouse automation (clicks, scrolling). Supports PID-targeted scroll via `scroll(x:y:deltaX:deltaY:targetPid:)`.
- **Screen/ScreenCaptureService.swift**: ScreenCaptureKit-based screen capture (actor). Finds windows including off-screen ones for background capture.
- **Accessibility/AccessibilityService.swift**: AXUIElement-based UI element tree traversal, element search, and action execution (`@MainActor` singleton)
- **Accessibility/MenuService.swift**: Application menu discovery and triggering via accessibility APIs. Supports background mode (skip `app.activate()`).
- **Permissions/PermissionManager.swift**: Checks and requests Accessibility (`AXIsProcessTrusted`) and Screen Recording permissions
- **Models/APIModels.swift**: Codable request/response types for the HTTP API
- **Models/AccessibilityModels.swift**: Types for accessibility operations (`ElementPath`, `UIElementInfo`, `ElementQuery`, `AccessibilityAction`, etc.)

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
- `GET /screenshot` - Capture screen or specific window (supports `?app=Name` for background windows)
- `POST /click` - Click at coordinates
- `POST /click/element` - Click element by title/role/label (supports `use_accessibility_action` for background)
- `POST /type` - Type text (supports `pid`/`path`/`role`/`title` for background AX setValue)
- `POST /key` - Press key with modifiers (supports `pid` for PID-targeted, `path` for AX action)
- `POST /scroll` - Scroll at position (supports `pid`/`path` for background targeting)
- `POST /wait` - Wait for element to appear/disappear/become enabled
- `GET /accessibility/tree` - Get UI element hierarchy (supports `?format=compact`)
- `GET /accessibility/elements` - Find elements by role/title/label
- `GET /accessibility/focused` - Get focused element
- `POST /accessibility/action` - Perform action on element (press, setValue, focus, etc.)
- `GET /menu` - Get application menu structure
- `POST /menu` - Trigger menu item (supports `background: true` to skip activation)

## Key Patterns

- Core services use singletons (`.shared`) for shared state
- `ScreenCaptureService` and `GeisterhandServer` are actors for thread safety
- `AccessibilityService` and `MenuService` are `@MainActor` singletons (AX APIs require main thread)
- Route handlers that use accessibility services are marked `@MainActor`
- Tests use Swift Testing framework (`@Test`, `#expect`)
- JSON uses snake_case encoding/decoding strategy
- **Background mode**: Input routes (`/type`, `/key`, `/scroll`) accept optional `pid`, `path`, and element query params. When present, they use accessibility APIs or PID-targeted CGEvents instead of global events, enabling automation of background apps without bringing them to the foreground.
