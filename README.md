# Geisterhand

A macOS screen automation tool that provides an HTTP API and CLI for controlling mouse, keyboard, and capturing screenshots.

## Requirements

- macOS 14.0+
- Swift 6.0+
- Accessibility permission (for keyboard/mouse control)
- Screen Recording permission (for screenshots)

## Installation

### Build from source

```bash
git clone https://github.com/Geisterhand-io/macos.git
cd macos
swift build -c release
```

The binaries will be in `.build/release/`:
- `geisterhand` - CLI tool
- `GeisterhandApp` - Menu bar application

## Usage

### Menu Bar App

Run the menu bar app for persistent background operation:

```bash
swift run GeisterhandApp
```

The icon color indicates status:
- Green: All permissions granted, server running
- Yellow: Missing some permissions
- Red: Server not running

### CLI

```bash
# Check status and permissions
geisterhand status

# Take a screenshot
geisterhand screenshot -o screenshot.png
geisterhand screenshot --base64

# Click at coordinates
geisterhand click 100 200
geisterhand click 100 200 --button right --count 2
geisterhand click 100 200 --cmd --shift

# Type text
geisterhand type "Hello World"
geisterhand type "Slow typing" --delay 50

# Press keys with modifiers
geisterhand key return
geisterhand key s --cmd          # Cmd+S
geisterhand key a --cmd --shift  # Cmd+Shift+A

# Scroll
geisterhand scroll 500 300 --delta -100  # Scroll up
geisterhand scroll 500 300 --delta-x 50  # Scroll right

# Run HTTP server standalone
geisterhand server --host 127.0.0.1 --port 7676
```

### HTTP API

The server runs on `127.0.0.1:7676` by default.

#### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | API info and available endpoints |
| GET | `/status` | System info and permission status |
| GET | `/health` | Health check |
| GET | `/screenshot` | Capture screen or app window (`?app=Safari`) |
| POST | `/click` | Click at coordinates |
| POST | `/click/element` | Click element by title/role/label |
| POST | `/type` | Type text (supports background mode) |
| POST | `/key` | Press key with modifiers (supports background mode) |
| POST | `/scroll` | Scroll at position (supports background mode) |
| POST | `/wait` | Wait for element to appear/disappear |
| GET | `/accessibility/tree` | Get UI element hierarchy |
| GET | `/accessibility/elements` | Find elements by criteria |
| GET | `/accessibility/focused` | Get focused element |
| POST | `/accessibility/action` | Perform action on element |
| GET | `/menu` | Get application menu structure |
| POST | `/menu` | Trigger menu item (supports background mode) |

#### Examples

```bash
# Get status
curl http://127.0.0.1:7676/status

# Take screenshot (full screen or specific app)
curl http://127.0.0.1:7676/screenshot
curl "http://127.0.0.1:7676/screenshot?app=Safari&format=base64"

# Click at coordinates
curl -X POST http://127.0.0.1:7676/click \
  -H "Content-Type: application/json" \
  -d '{"x": 100, "y": 200, "button": "left"}'

# Click element by title (with optional accessibility action for background)
curl -X POST http://127.0.0.1:7676/click/element \
  -H "Content-Type: application/json" \
  -d '{"title": "OK", "use_accessibility_action": true}'

# Type text
curl -X POST http://127.0.0.1:7676/type \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello World"}'

# Type into background app (accessibility setValue)
curl -X POST http://127.0.0.1:7676/type \
  -H "Content-Type: application/json" \
  -d '{"text": "hello@example.com", "pid": 1234, "role": "AXTextField"}'

# Press Cmd+S
curl -X POST http://127.0.0.1:7676/key \
  -H "Content-Type: application/json" \
  -d '{"key": "s", "modifiers": ["cmd"]}'

# Press key targeted at background app
curl -X POST http://127.0.0.1:7676/key \
  -H "Content-Type: application/json" \
  -d '{"key": "return", "pid": 1234}'

# Scroll
curl -X POST http://127.0.0.1:7676/scroll \
  -H "Content-Type: application/json" \
  -d '{"x": 500, "y": 300, "delta_y": -100}'

# Trigger menu item (background mode)
curl -X POST http://127.0.0.1:7676/menu \
  -H "Content-Type: application/json" \
  -d '{"app": "TextEdit", "path": ["Edit", "Select All"], "background": true}'
```

See [LLM_API_GUIDE.md](LLM_API_GUIDE.md) for comprehensive API documentation including background automation patterns.

## Permissions

Geisterhand requires two macOS permissions:

1. **Accessibility** - For keyboard and mouse control
   - System Settings > Privacy & Security > Accessibility

2. **Screen Recording** - For screenshots
   - System Settings > Privacy & Security > Screen Recording

The app will prompt for these permissions on first use, or you can grant them manually.

## Author

Skelpo GmbH

## License

MIT
