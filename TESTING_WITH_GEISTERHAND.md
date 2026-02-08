# Testing Apps with Geisterhand

Drop this into your project's `CLAUDE.md` (or reference it) so Claude Code knows how to use Geisterhand for UI testing and automation.

---

## Prerequisites

```bash
# Install (build from source)
git clone https://github.com/Geisterhand-io/macos.git && cd macos
swift build -c release && cp .build/release/geisterhand /usr/local/bin/
```

**Required macOS permissions** (grant in System Settings > Privacy & Security):
- Accessibility (keyboard/mouse control)
- Screen Recording (screenshots)

---

## How It Works

`geisterhand run` launches (or attaches to) an app and starts an HTTP server scoped to it. It prints a JSON line with the connection details, then blocks until the app quits:

```bash
geisterhand run TextEdit
# {"app":"TextEdit","host":"127.0.0.1","pid":12345,"port":49152}
```

The server auto-selects a free port (use `--port` to pin one). All API requests are scoped to the target app's PID. When the target app terminates, the server exits automatically.

---

## CLAUDE.md Snippet

Paste the section below into your project's `CLAUDE.md`. Replace `[YourApp]` with your app name.

````markdown
## UI Testing with Geisterhand

This project uses [Geisterhand](https://github.com/Geisterhand-io/macos) for UI automation and testing.
All requests/responses use `snake_case` JSON.

### Starting the App Under Test

```bash
# Launch [YourApp] and start Geisterhand server scoped to it
geisterhand run [YourApp] &
# Reads the JSON line to get PORT and PID
```

You can pass an app name (`Calculator`), bundle path (`/Applications/Safari.app`), or bundle identifier. If the app is already running, Geisterhand attaches to it.

### Testing Workflow

1. **Start Geisterhand:** `geisterhand run [YourApp] &` — note the `port` and `pid` from the JSON output
2. **Verify permissions:** `GET /status`
3. **Inspect UI:** `GET /accessibility/tree?format=compact` to see what's on screen
4. **Interact:** click, type, press keys, trigger menus
5. **Assert:** take screenshots, read element values, wait for conditions
6. **Repeat**

### Key Patterns

- Prefer `/click/element` and `/accessibility/action` over coordinate-based `/click`
- Use `/wait` instead of `sleep` between steps
- Use `?format=compact` on `/accessibility/tree` for readable output
- Use `/screenshot` to capture the app's window (scoped automatically)
- Use background mode (`pid`, `path`, `use_accessibility_action`) when you don't want to steal focus
````

---

## API Quick Reference

All endpoints run on the host/port from the `geisterhand run` JSON output (e.g. `http://127.0.0.1:49152`).

| Action | Method | Endpoint | Key Params |
|--------|--------|----------|------------|
| Server status | GET | `/status` | - |
| Screenshot | GET | `/screenshot` | `app`, `format`, `windowId` |
| Click coordinates | POST | `/click` | `x`, `y`, `button`, `click_count`, `modifiers` |
| Click element | POST | `/click/element` | `title`, `title_contains`, `role`, `label`, `pid`, `use_accessibility_action` |
| Type text | POST | `/type` | `text`, `delay_ms`, `pid`\*, `path`\*, `role`\*, `title`\* |
| Press key | POST | `/key` | `key`, `modifiers`, `pid`\*, `path`\* |
| Scroll | POST | `/scroll` | `x`, `y`, `delta_x`, `delta_y`, `pid`\*, `path`\* |
| Wait for element | POST | `/wait` | `title`, `role`, `condition`, `timeout_ms` |
| UI tree | GET | `/accessibility/tree` | `pid`, `maxDepth`, `format` |
| Find elements | GET | `/accessibility/elements` | `role`, `title`, `titleContains`, `labelContains`, `valueContains`, `pid` |
| Focused element | GET | `/accessibility/focused` | `pid` |
| Perform action | POST | `/accessibility/action` | `path`, `action`, `value` |
| Get menus | GET | `/menu` | `app` |
| Trigger menu | POST | `/menu` | `app`, `path`, `background` |

\* = background mode param

---

## Core Concepts

### Element Paths

Every UI element has a `path` of the form `{"pid": 1234, "path": [0, 0, 1, 3]}`. This is an array of child indices from the app root. You get paths from `/accessibility/tree`, `/accessibility/elements`, or `/click/element` responses. Pass them to `/accessibility/action`, `/type`, `/key`, `/scroll` for targeted interaction.

Paths are stable within a session but change when the UI structure changes (windows open/close, views reload). Re-query if an action fails with a stale path.

### Foreground vs Background Mode

**Foreground (default):** Uses global CGEvents. The app must be frontmost.

**Background:** Uses accessibility APIs or AX-targeted keyboard events. The app stays behind other windows.

| Endpoint | How to Enable Background | Mechanism |
|----------|-------------------------|-----------|
| `/type` | Add `pid` + element query or `path` | Accessibility `setValue` (replaces entire field) |
| `/key` | Add `pid` | AXUIElement keyboard event posted to app |
| `/key` | Add `path` | Maps key to AX action (return/enter->confirm, escape->cancel, space->press) |
| `/scroll` | Add `pid` or `path` | PID-targeted scroll event |
| `/click/element` | Set `use_accessibility_action: true` | AX press action |
| `/menu` | Set `background: true` | AX menu trigger without `app.activate()` |
| `/screenshot` | Add `?app=Name` | ScreenCaptureKit window capture (works off-screen) |

### Wait Conditions

Use `/wait` instead of `sleep` to synchronize with UI state:

| Condition | Meaning |
|-----------|---------|
| `exists` (default) | Element appears in the UI |
| `not_exists` | Element disappears (e.g., loading spinner gone) |
| `enabled` | Element exists and is enabled (e.g., submit button becomes clickable) |
| `focused` | Element exists and has focus |

Timeout defaults to 5000ms (max 60000ms). Poll interval defaults to 100ms.

### Common Accessibility Roles

| Role | What It Is |
|------|-----------|
| `AXButton` | Buttons |
| `AXTextField` | Single-line text input |
| `AXTextArea` | Multi-line text input |
| `AXSecureTextField` | Password field |
| `AXCheckBox` | Checkbox |
| `AXRadioButton` | Radio button |
| `AXPopUpButton` | Dropdown/popup |
| `AXComboBox` | Combo box |
| `AXSlider` | Slider |
| `AXMenuItem` | Menu item |
| `AXStaticText` | Label / static text |
| `AXLink` | Hyperlink |
| `AXImage` | Image |
| `AXTable` | Table |
| `AXRow` | Table row |
| `AXWindow` | Window |
| `AXSheet` | Sheet/dialog |
| `AXToolbar` | Toolbar |
| `AXTabGroup` | Tab bar |

### Available Actions (`/accessibility/action`)

| Action | Use For |
|--------|---------|
| `press` | Click a button, toggle a checkbox |
| `setValue` | Set text field content (requires `value` param) |
| `focus` | Move focus to an element |
| `confirm` | Confirm a dialog (like pressing Return) |
| `cancel` | Dismiss a dialog (like pressing Escape) |
| `increment` | Increase a stepper/slider value |
| `decrement` | Decrease a stepper/slider value |
| `showMenu` | Open a context/dropdown menu |
| `pick` | Select an item (date pickers, etc.) |

### Key Names for `/key`

- **Letters:** `a`-`z`
- **Numbers:** `0`-`9`
- **Function keys:** `f1`-`f12`
- **Navigation:** `up`, `down`, `left`, `right`, `home`, `end`, `pageup`, `pagedown`
- **Special:** `return`, `tab`, `space`, `delete`, `escape`
- **Modifiers** (array): `cmd`, `ctrl`, `alt`, `shift`, `fn`

---

## Testing Recipes

In all recipes below, `$PORT` and `$PID` come from the `geisterhand run` JSON output.

### Recipe 1: Launch App and Verify Window Appears

```bash
# Launch the app with Geisterhand
geisterhand run YourApp &
# Parse PORT and PID from the JSON output

# Wait for main window
curl -X POST http://127.0.0.1:$PORT/wait \
  -H "Content-Type: application/json" \
  -d '{"role": "AXWindow", "title_contains": "YourApp", "timeout_ms": 10000}'

# Verify the window exists
curl "http://127.0.0.1:$PORT/accessibility/tree?format=compact&maxDepth=2"
```

### Recipe 2: Fill a Form and Submit

```bash
# Click username field and type
curl -X POST http://127.0.0.1:$PORT/click/element \
  -H "Content-Type: application/json" \
  -d "{\"title_contains\": \"Username\", \"role\": \"AXTextField\", \"pid\": $PID}"

curl -X POST http://127.0.0.1:$PORT/type \
  -H "Content-Type: application/json" \
  -d '{"text": "testuser"}'

# Click password field and type
curl -X POST http://127.0.0.1:$PORT/click/element \
  -H "Content-Type: application/json" \
  -d "{\"title_contains\": \"Password\", \"role\": \"AXSecureTextField\", \"pid\": $PID}"

curl -X POST http://127.0.0.1:$PORT/type \
  -H "Content-Type: application/json" \
  -d '{"text": "testpass123"}'

# Click Submit
curl -X POST http://127.0.0.1:$PORT/click/element \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"Submit\", \"role\": \"AXButton\", \"pid\": $PID}"

# Wait for success indicator
curl -X POST http://127.0.0.1:$PORT/wait \
  -H "Content-Type: application/json" \
  -d "{\"title_contains\": \"Welcome\", \"pid\": $PID, \"timeout_ms\": 5000}"
```

### Recipe 3: Fill Form in Background (No Focus Steal)

```bash
# Set text field values directly via accessibility (app stays in background)
curl -X POST http://127.0.0.1:$PORT/type \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"testuser\", \"pid\": $PID, \"role\": \"AXTextField\", \"title_contains\": \"Username\"}"

curl -X POST http://127.0.0.1:$PORT/type \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"testpass\", \"pid\": $PID, \"role\": \"AXSecureTextField\"}"

# Click submit via accessibility action (no mouse movement)
curl -X POST http://127.0.0.1:$PORT/click/element \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"Submit\", \"pid\": $PID, \"use_accessibility_action\": true}"
```

### Recipe 4: Navigate Menus

```bash
# Discover available menus
curl "http://127.0.0.1:$PORT/menu?app=YourApp"

# Trigger File > New Document
curl -X POST http://127.0.0.1:$PORT/menu \
  -H "Content-Type: application/json" \
  -d '{"app": "YourApp", "path": ["File", "New Document"]}'

# Wait for new document window
curl -X POST http://127.0.0.1:$PORT/wait \
  -H "Content-Type: application/json" \
  -d '{"title": "Untitled", "role": "AXWindow", "timeout_ms": 3000}'
```

### Recipe 5: Scroll and Find Off-Screen Content

```bash
# Look for an element that might be off-screen
RESULT=$(curl -s "http://127.0.0.1:$PORT/accessibility/elements?titleContains=Section%205&pid=$PID")

# If not found, scroll down and try again
curl -X POST http://127.0.0.1:$PORT/scroll \
  -H "Content-Type: application/json" \
  -d "{\"x\": 500, \"y\": 400, \"delta_y\": -300}"

# Wait a moment for scroll to settle, then search again
curl -X POST http://127.0.0.1:$PORT/wait \
  -H "Content-Type: application/json" \
  -d "{\"title_contains\": \"Section 5\", \"pid\": $PID, \"timeout_ms\": 2000}"
```

### Recipe 6: Screenshot-Based Verification

```bash
# Capture just your app's window
curl "http://127.0.0.1:$PORT/screenshot?app=YourApp&format=base64" -o result.json

# Capture as PNG file
curl "http://127.0.0.1:$PORT/screenshot?app=YourApp" --output current_state.png

# Capture as JPEG (smaller)
curl "http://127.0.0.1:$PORT/screenshot?app=YourApp&format=jpeg" --output current_state.jpg
```

### Recipe 7: Read Element Values (Assertions)

```bash
# Check if a label shows the expected text
curl -s "http://127.0.0.1:$PORT/accessibility/elements?role=AXStaticText&valueContains=Success&pid=$PID"

# Check if a button is enabled
curl -s "http://127.0.0.1:$PORT/accessibility/elements?role=AXButton&title=Submit&pid=$PID"
# Look at "is_enabled" in the response

# Check if a checkbox is checked (value = "1" means checked)
curl -s "http://127.0.0.1:$PORT/accessibility/elements?role=AXCheckBox&title=Remember%20Me&pid=$PID"
# Look at "value" in the response
```

### Recipe 8: Keyboard Shortcuts

```bash
# Save (Cmd+S)
curl -X POST http://127.0.0.1:$PORT/key \
  -H "Content-Type: application/json" \
  -d '{"key": "s", "modifiers": ["cmd"]}'

# Undo (Cmd+Z)
curl -X POST http://127.0.0.1:$PORT/key \
  -H "Content-Type: application/json" \
  -d '{"key": "z", "modifiers": ["cmd"]}'

# Select All (Cmd+A), Copy (Cmd+C)
curl -X POST http://127.0.0.1:$PORT/key \
  -H "Content-Type: application/json" \
  -d '{"key": "a", "modifiers": ["cmd"]}'

curl -X POST http://127.0.0.1:$PORT/key \
  -H "Content-Type: application/json" \
  -d '{"key": "c", "modifiers": ["cmd"]}'

# Tab between fields
curl -X POST http://127.0.0.1:$PORT/key \
  -H "Content-Type: application/json" \
  -d '{"key": "tab"}'
```

### Recipe 9: Handle Dialogs and Sheets

```bash
# Wait for a dialog to appear
curl -X POST http://127.0.0.1:$PORT/wait \
  -H "Content-Type: application/json" \
  -d "{\"role\": \"AXSheet\", \"pid\": $PID, \"timeout_ms\": 5000}"

# Click OK/Cancel on the dialog
curl -X POST http://127.0.0.1:$PORT/click/element \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"OK\", \"role\": \"AXButton\", \"pid\": $PID}"

# Or dismiss with Escape
curl -X POST http://127.0.0.1:$PORT/key \
  -H "Content-Type: application/json" \
  -d '{"key": "escape"}'

# Wait for dialog to disappear
curl -X POST http://127.0.0.1:$PORT/wait \
  -H "Content-Type: application/json" \
  -d "{\"role\": \"AXSheet\", \"condition\": \"not_exists\", \"pid\": $PID, \"timeout_ms\": 3000}"
```

### Recipe 10: Save File to Specific Path

```bash
# Trigger Save As
curl -X POST http://127.0.0.1:$PORT/key \
  -H "Content-Type: application/json" \
  -d '{"key": "s", "modifiers": ["cmd", "shift"]}'

# Wait for save dialog
curl -X POST http://127.0.0.1:$PORT/wait \
  -H "Content-Type: application/json" \
  -d '{"role": "AXSheet", "timeout_ms": 3000}'

# Open Go to Folder
curl -X POST http://127.0.0.1:$PORT/key \
  -H "Content-Type: application/json" \
  -d '{"key": "g", "modifiers": ["cmd", "shift"]}'

sleep 0.5

# Type path and confirm
curl -X POST http://127.0.0.1:$PORT/type \
  -H "Content-Type: application/json" \
  -d '{"text": "/tmp/test-output"}'

curl -X POST http://127.0.0.1:$PORT/key \
  -H "Content-Type: application/json" \
  -d '{"key": "return"}'

sleep 0.5

# Type filename
curl -X POST http://127.0.0.1:$PORT/type \
  -H "Content-Type: application/json" \
  -d '{"text": "test-result.txt"}'

# Save
curl -X POST http://127.0.0.1:$PORT/key \
  -H "Content-Type: application/json" \
  -d '{"key": "return"}'
```

---

## Best Practices

### 1. Always Start with `geisterhand run`
Use `geisterhand run YourApp &` to launch the app and server together. Parse the JSON output to get `port` and `pid`. Then verify with `GET /status`.

### 2. Use `/wait` Instead of `sleep`
`sleep` is fragile. Use `/wait` to synchronize with actual UI state:
```bash
# Bad
sleep 2

# Good
curl -X POST http://127.0.0.1:$PORT/wait \
  -d '{"title": "Ready", "timeout_ms": 5000}'
```

### 3. Use Semantic Selectors Over Coordinates
Coordinates break when windows move or resize. Use `title`, `title_contains`, `role`, and `label` to find elements:
```bash
# Bad - breaks if window moves
curl -X POST http://127.0.0.1:$PORT/click -d '{"x": 540, "y": 315}'

# Good - finds element wherever it is
curl -X POST http://127.0.0.1:$PORT/click/element \
  -d '{"title": "Submit", "role": "AXButton"}'
```

### 4. Scope to PID
Always pass `pid` when testing a specific app. Without it, commands target the frontmost app, which may not be yours:
```bash
curl "http://127.0.0.1:$PORT/accessibility/elements?role=AXButton&pid=$PID"
```

### 5. Use Compact Tree Format for Discovery
When exploring an unfamiliar UI, use compact format for a scannable flat list:
```bash
curl "http://127.0.0.1:$PORT/accessibility/tree?pid=$PID&format=compact&maxDepth=4"
```

### 6. Re-query Stale Paths
Element paths change when the UI updates. If an action fails, re-query the element before retrying.

### 7. Chain Actions with `/wait`
Build reliable sequences by waiting for each step to complete:
```bash
# Click button -> wait for result -> verify
curl -X POST http://127.0.0.1:$PORT/click/element -d '{"title": "Load"}'
curl -X POST http://127.0.0.1:$PORT/wait -d '{"title": "Loading", "condition": "not_exists", "timeout_ms": 10000}'
curl "http://127.0.0.1:$PORT/accessibility/elements?titleContains=Results&pid=$PID"
```

### 8. Use Background Mode When Possible
Background mode prevents focus theft and lets tests run without disrupting the user:
```bash
# Set text without activating the app
curl -X POST http://127.0.0.1:$PORT/type \
  -d "{\"text\": \"value\", \"pid\": $PID, \"role\": \"AXTextField\"}"
```

### 9. Use Screenshots for Debugging
When a test fails, capture the current state:
```bash
curl "http://127.0.0.1:$PORT/screenshot?app=YourApp" --output debug.png
```

### 10. Handle Missing Permissions Gracefully
Check `/status` at the start and report which permissions are missing instead of getting cryptic failures mid-test.

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `connection refused` | Server not running | Run `geisterhand run YourApp &` |
| `accessibility: false` in `/status` | Missing permission | Grant in System Settings > Privacy & Security > Accessibility |
| `screen_recording: false` in `/status` | Missing permission | Grant in System Settings > Privacy & Security > Screen Recording |
| Element not found | Wrong PID or element not visible | Check PID from `geisterhand run` output, use `/accessibility/tree` to inspect UI |
| Action failed on element | Stale path or element disabled | Re-query element, check `is_enabled` |
| `/type` background mode replaces text | Expected behavior | Background `/type` uses `setValue` which sets the whole field |
| `/key` with `path` doesn't work | Only 3 keys supported | Use `pid` instead of `path` for arbitrary keys |
| Menu not found | Case-sensitive match | Use exact titles from `GET /menu` response |

---

## Response Format Reference

All responses include `"success": boolean`. On error, `"error": string` is present.

**Element info** (from `/accessibility/elements`, `/click/element`, `/wait`):
```json
{
  "path": {"pid": 1234, "path": [0, 0, 1, 3]},
  "role": "AXButton",
  "title": "Submit",
  "label": "Submit form",
  "value": null,
  "frame": {"x": 100, "y": 200, "width": 80, "height": 30},
  "is_enabled": true,
  "is_focused": false,
  "actions": ["AXPress"]
}
```

**App info** (from `/status`, accessibility endpoints):
```json
{
  "name": "YourApp",
  "bundle_identifier": "com.example.yourapp",
  "process_identifier": 1234
}
```
