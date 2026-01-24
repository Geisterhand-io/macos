# Geisterhand API Guide for LLMs

Geisterhand is a macOS automation tool that provides HTTP endpoints to control mouse, keyboard, and capture screenshots. The server runs on `http://127.0.0.1:7676`.

## Quick Reference

| Action | Method | Endpoint | Key Parameters |
|--------|--------|----------|----------------|
| Check status | GET | `/status` | - |
| Take screenshot | GET | `/screenshot` | - |
| Click mouse | POST | `/click` | `x`, `y` |
| Type text | POST | `/type` | `text` |
| Press key | POST | `/key` | `key`, `modifiers` |
| Scroll | POST | `/scroll` | `x`, `y`, `delta_x`, `delta_y` |

## Endpoints

### GET /status

Returns system info, permissions, and frontmost app.

```bash
curl http://127.0.0.1:7676/status
```

Response:
```json
{
  "status": "ok",
  "version": "1.0.0",
  "server_running": true,
  "permissions": {
    "accessibility": true,
    "screen_recording": true
  },
  "frontmost_app": {
    "name": "TextEdit",
    "bundle_identifier": "com.apple.TextEdit",
    "process_identifier": 12345
  },
  "screen_size": {
    "width": 1920,
    "height": 1080
  }
}
```

### GET /screenshot

Captures the screen and returns base64-encoded PNG.

```bash
curl http://127.0.0.1:7676/screenshot
```

Response:
```json
{
  "success": true,
  "format": "png",
  "width": 1920,
  "height": 1080,
  "data": "iVBORw0KGgoAAAANSUhEUgAA..."
}
```

### POST /click

Clicks at screen coordinates.

```bash
# Left click at position (500, 300)
curl -X POST http://127.0.0.1:7676/click \
  -H "Content-Type: application/json" \
  -d '{"x": 500, "y": 300}'

# Right click
curl -X POST http://127.0.0.1:7676/click \
  -H "Content-Type: application/json" \
  -d '{"x": 500, "y": 300, "button": "right"}'

# Double click
curl -X POST http://127.0.0.1:7676/click \
  -H "Content-Type: application/json" \
  -d '{"x": 500, "y": 300, "click_count": 2}'

# Cmd+click
curl -X POST http://127.0.0.1:7676/click \
  -H "Content-Type: application/json" \
  -d '{"x": 500, "y": 300, "modifiers": ["cmd"]}'
```

Parameters:
- `x` (required): X coordinate
- `y` (required): Y coordinate
- `button`: `"left"` (default), `"right"`, or `"center"`
- `click_count`: Number of clicks (default: 1)
- `modifiers`: Array of `"cmd"`, `"ctrl"`, `"alt"`, `"shift"`

### POST /type

Types text. Works with any keyboard layout.

```bash
# Type simple text
curl -X POST http://127.0.0.1:7676/type \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, World!"}'

# Type with delay between characters (ms)
curl -X POST http://127.0.0.1:7676/type \
  -H "Content-Type: application/json" \
  -d '{"text": "Slow typing", "delay_ms": 100}'
```

Parameters:
- `text` (required): Text to type (supports unicode, newlines, special characters)
- `delay_ms`: Delay between keystrokes in milliseconds

### POST /key

Presses a key with optional modifiers. Use this for keyboard shortcuts.

```bash
# Press Enter
curl -X POST http://127.0.0.1:7676/key \
  -H "Content-Type: application/json" \
  -d '{"key": "return"}'

# Press Cmd+S (save)
curl -X POST http://127.0.0.1:7676/key \
  -H "Content-Type: application/json" \
  -d '{"key": "s", "modifiers": ["cmd"]}'

# Press Cmd+Shift+G (Go to folder in save dialogs)
curl -X POST http://127.0.0.1:7676/key \
  -H "Content-Type: application/json" \
  -d '{"key": "g", "modifiers": ["cmd", "shift"]}'

# Press Cmd+Space (Spotlight)
curl -X POST http://127.0.0.1:7676/key \
  -H "Content-Type: application/json" \
  -d '{"key": "space", "modifiers": ["cmd"]}'
```

Available keys:
- Letters: `a`-`z`
- Numbers: `0`-`9`
- Function keys: `f1`-`f12`
- Special: `return`, `tab`, `space`, `delete`, `escape`, `up`, `down`, `left`, `right`, `home`, `end`, `pageup`, `pagedown`

Modifiers: `"cmd"`, `"ctrl"`, `"alt"`, `"shift"`, `"fn"`

### POST /scroll

Scrolls at a position.

```bash
# Scroll down
curl -X POST http://127.0.0.1:7676/scroll \
  -H "Content-Type: application/json" \
  -d '{"x": 500, "y": 300, "delta_y": -100}'

# Scroll up
curl -X POST http://127.0.0.1:7676/scroll \
  -H "Content-Type: application/json" \
  -d '{"x": 500, "y": 300, "delta_y": 100}'

# Scroll right
curl -X POST http://127.0.0.1:7676/scroll \
  -H "Content-Type: application/json" \
  -d '{"x": 500, "y": 300, "delta_x": -50}'
```

Parameters:
- `x` (required): X coordinate
- `y` (required): Y coordinate
- `delta_x`: Horizontal scroll amount (negative = right)
- `delta_y`: Vertical scroll amount (negative = down)

## Common Workflows

### Open an application via Spotlight

```bash
# 1. Open Spotlight
curl -X POST http://127.0.0.1:7676/key -H "Content-Type: application/json" \
  -d '{"key": "space", "modifiers": ["cmd"]}'
sleep 0.5

# 2. Type app name
curl -X POST http://127.0.0.1:7676/type -H "Content-Type: application/json" \
  -d '{"text": "Safari"}'
sleep 0.3

# 3. Press Enter to launch
curl -X POST http://127.0.0.1:7676/key -H "Content-Type: application/json" \
  -d '{"key": "return"}'
```

### Save a file to a specific location

```bash
# 1. Open save dialog
curl -X POST http://127.0.0.1:7676/key -H "Content-Type: application/json" \
  -d '{"key": "s", "modifiers": ["cmd"]}'
sleep 1

# 2. Open "Go to folder" sheet
curl -X POST http://127.0.0.1:7676/key -H "Content-Type: application/json" \
  -d '{"key": "g", "modifiers": ["cmd", "shift"]}'
sleep 0.5

# 3. Type path
curl -X POST http://127.0.0.1:7676/type -H "Content-Type: application/json" \
  -d '{"text": "~/Downloads"}'
sleep 0.3

# 4. Navigate to folder
curl -X POST http://127.0.0.1:7676/key -H "Content-Type: application/json" \
  -d '{"key": "return"}'
sleep 0.5

# 5. Type filename
curl -X POST http://127.0.0.1:7676/type -H "Content-Type: application/json" \
  -d '{"text": "myfile.txt"}'
sleep 0.3

# 6. Save
curl -X POST http://127.0.0.1:7676/key -H "Content-Type: application/json" \
  -d '{"key": "return"}'
```

### Copy and paste

```bash
# Select all
curl -X POST http://127.0.0.1:7676/key -H "Content-Type: application/json" \
  -d '{"key": "a", "modifiers": ["cmd"]}'

# Copy
curl -X POST http://127.0.0.1:7676/key -H "Content-Type: application/json" \
  -d '{"key": "c", "modifiers": ["cmd"]}'

# Paste
curl -X POST http://127.0.0.1:7676/key -H "Content-Type: application/json" \
  -d '{"key": "v", "modifiers": ["cmd"]}'
```

## Tips for LLMs

1. **Always add delays** between actions (0.3-1 second) to let the UI respond
2. **Check /status first** to verify the server is running and has permissions
3. **Use /screenshot** to see the current screen state before/after actions
4. **Coordinates**: (0,0) is top-left corner of the main display
5. **Text input**: Use `/type` for text, `/key` for shortcuts and special keys
6. **All JSON uses snake_case** for field names
