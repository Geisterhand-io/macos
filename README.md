# Geisterhand

A macOS screen automation tool that provides an HTTP API and CLI for controlling mouse, keyboard, and capturing screenshots.

## Requirements

- macOS 13.0+
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
| GET | `/screenshot` | Capture screen (base64 PNG) |
| POST | `/click` | Click at coordinates |
| POST | `/type` | Type text |
| POST | `/key` | Press key with modifiers |
| POST | `/scroll` | Scroll at position |

#### Examples

```bash
# Get status
curl http://127.0.0.1:7676/status

# Take screenshot
curl http://127.0.0.1:7676/screenshot

# Click
curl -X POST http://127.0.0.1:7676/click \
  -H "Content-Type: application/json" \
  -d '{"x": 100, "y": 200, "button": "left"}'

# Type text
curl -X POST http://127.0.0.1:7676/type \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello World"}'

# Press Cmd+S
curl -X POST http://127.0.0.1:7676/key \
  -H "Content-Type: application/json" \
  -d '{"key": "s", "modifiers": ["cmd"]}'

# Scroll
curl -X POST http://127.0.0.1:7676/scroll \
  -H "Content-Type: application/json" \
  -d '{"x": 500, "y": 300, "deltaY": -100}'
```

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
