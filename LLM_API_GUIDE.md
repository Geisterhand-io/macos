# Geisterhand API Guide for LLMs

Geisterhand is a macOS automation tool that provides HTTP endpoints to control mouse, keyboard, and capture screenshots. The server runs on `http://127.0.0.1:7676`.

## Quick Reference

| Action | Method | Endpoint | Key Parameters |
|--------|--------|----------|----------------|
| Check status | GET | `/status` | - |
| Take screenshot | GET | `/screenshot` | `app`, `windowId` |
| Click mouse | POST | `/click` | `x`, `y` |
| Click element | POST | `/click/element` | `title`, `role`, `pid` |
| Type text | POST | `/type` | `text`, `pid`\*, `path`\*, `role`\* |
| Press key | POST | `/key` | `key`, `modifiers`, `pid`\*, `path`\* |
| Scroll | POST | `/scroll` | `x`, `y`, `delta_x`, `delta_y`, `pid`\*, `path`\* |
| Wait for element | POST | `/wait` | `title`, `role`, `timeout_ms` |
| Get UI tree | GET | `/accessibility/tree` | `pid`, `maxDepth`, `format` |
| Find elements | GET | `/accessibility/elements` | `role`, `title`, `titleContains`, `labelContains` |
| Get focused element | GET | `/accessibility/focused` | `pid` |
| Perform action | POST | `/accessibility/action` | `path`, `action`, `value` |
| Get menus | GET | `/menu` | `app` |
| Trigger menu | POST | `/menu` | `app`, `path`, `background`\* |

\* = optional background mode parameter (see [Background Automation](#background-automation))

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

Captures the screen (or a specific app window) and returns the image.

```bash
# Capture entire screen
curl http://127.0.0.1:7676/screenshot

# Capture specific app's window (recommended - less noise, faster)
curl "http://127.0.0.1:7676/screenshot?app=Safari&format=base64"

# Capture by window ID
curl "http://127.0.0.1:7676/screenshot?windowId=12345&format=base64"

# Get raw PNG instead of JSON/base64
curl "http://127.0.0.1:7676/screenshot?app=TextEdit" --output screenshot.png
```

Parameters:
- `app`: Application name for app-specific screenshot (case-insensitive, partial match)
- `windowId`: Specific window ID to capture
- `format`: `"png"` (default, raw image), `"base64"` (JSON with base64 data), or `"jpeg"`
- `display`: Display ID for multi-monitor setups

Response (format=base64):
```json
{
  "success": true,
  "format": "base64",
  "width": 1200,
  "height": 800,
  "data": "iVBORw0KGgoAAAANSUhEUgAA...",
  "window": {
    "window_id": 12345,
    "title": "Untitled",
    "app_name": "TextEdit",
    "bundle_identifier": "com.apple.TextEdit",
    "frame": {"x": 100, "y": 100, "width": 1200, "height": 800},
    "is_on_screen": true
  }
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

### POST /click/element

**Click an element by its semantic properties (title, role, label).** This is easier than finding coordinates manually - just specify what you want to click.

```bash
# Click a button by title
curl -X POST http://127.0.0.1:7676/click/element \
  -H "Content-Type: application/json" \
  -d '{"title": "OK"}'

# Click a button by role and title
curl -X POST http://127.0.0.1:7676/click/element \
  -H "Content-Type: application/json" \
  -d '{"title": "Submit", "role": "AXButton"}'

# Click in a specific app
curl -X POST http://127.0.0.1:7676/click/element \
  -H "Content-Type: application/json" \
  -d '{"title_contains": "Sign In", "pid": 12345}'

# Use accessibility action instead of mouse click (more reliable)
curl -X POST http://127.0.0.1:7676/click/element \
  -H "Content-Type: application/json" \
  -d '{"title": "Cancel", "use_accessibility_action": true}'
```

Parameters:
- `title`: Exact title match
- `title_contains`: Title contains string (case-insensitive)
- `role`: Accessibility role (e.g., `"AXButton"`, `"AXTextField"`)
- `label`: Accessibility label/description
- `pid`: Process ID (uses frontmost app if not specified)
- `use_accessibility_action`: If true, uses AX press action instead of mouse click (default: false)
- `button`: Mouse button for coordinate click (`"left"`, `"right"`)

Response:
```json
{
  "success": true,
  "element": {
    "role": "AXButton",
    "title": "OK",
    "label": null,
    "frame": {"x": 500, "y": 300, "width": 80, "height": 30}
  },
  "clicked_at": {"x": 540, "y": 315}
}
```

### POST /wait

**Wait for an element to appear, disappear, or reach a specific state.** Replaces unreliable `sleep` delays with intelligent polling.

```bash
# Wait for a button to appear (up to 5 seconds)
curl -X POST http://127.0.0.1:7676/wait \
  -H "Content-Type: application/json" \
  -d '{"title": "Sign In", "role": "AXButton"}'

# Wait with custom timeout
curl -X POST http://127.0.0.1:7676/wait \
  -H "Content-Type: application/json" \
  -d '{"title": "Loading", "condition": "not_exists", "timeout_ms": 10000}'

# Wait for element to become enabled
curl -X POST http://127.0.0.1:7676/wait \
  -H "Content-Type: application/json" \
  -d '{"title": "Submit", "condition": "enabled", "timeout_ms": 3000}'
```

Parameters:
- `title`: Exact title match
- `title_contains`: Title contains string (case-insensitive)
- `role`: Accessibility role
- `label`: Accessibility label
- `pid`: Process ID (uses frontmost app if not specified)
- `timeout_ms`: Maximum wait time in milliseconds (default: 5000, max: 60000)
- `poll_interval_ms`: Time between checks in milliseconds (default: 100)
- `condition`: What to wait for:
  - `"exists"` (default) - Element appears
  - `"not_exists"` - Element disappears
  - `"enabled"` - Element becomes enabled
  - `"focused"` - Element becomes focused

Response:
```json
{
  "success": true,
  "condition_met": true,
  "element": {
    "role": "AXButton",
    "title": "Sign In",
    "label": null,
    "frame": {"x": 500, "y": 300, "width": 100, "height": 40}
  },
  "waited_ms": 1250
}
```

Timeout response:
```json
{
  "success": true,
  "condition_met": false,
  "waited_ms": 5000,
  "error": "Timeout: condition 'exists' not met within 5000ms"
}
```

### POST /type

Types text. Works with any keyboard layout. Supports background mode via element targeting.

```bash
# Type simple text (frontmost app)
curl -X POST http://127.0.0.1:7676/type \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, World!"}'

# Type with delay between characters (ms)
curl -X POST http://127.0.0.1:7676/type \
  -H "Content-Type: application/json" \
  -d '{"text": "Slow typing", "delay_ms": 100}'

# Background mode: set value on element by query (no need to bring app to front)
curl -X POST http://127.0.0.1:7676/type \
  -H "Content-Type: application/json" \
  -d '{"text": "hello@example.com", "pid": 1234, "role": "AXTextField", "title_contains": "Email"}'

# Background mode: set value using direct element path
curl -X POST http://127.0.0.1:7676/type \
  -H "Content-Type: application/json" \
  -d '{"text": "hello", "path": {"pid": 1234, "path": [0, 0, 1, 2]}}'
```

Parameters:
- `text` (required): Text to type (supports unicode, newlines, special characters)
- `delay_ms`: Delay between keystrokes in milliseconds (CGEvent mode only)

Background mode parameters (when any of these are present, uses accessibility `setValue` instead of CGEvent):
- `pid`: Target app process ID (uses frontmost app if not specified)
- `path`: Direct element path (from `/accessibility/tree` or `/accessibility/elements`)
- `role`: Accessibility role to match (e.g., `"AXTextField"`)
- `title`: Element title (exact match)
- `title_contains`: Element title substring (case-insensitive)

**Note:** Background mode uses `setValue` which replaces the full field content atomically rather than typing character-by-character. This is more reliable for background automation but `delay_ms` has no effect.

### POST /key

Presses a key with optional modifiers. Use this for keyboard shortcuts. Supports background mode via PID targeting or accessibility actions.

```bash
# Press Enter (frontmost app)
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

# Background mode: PID-targeted key press (sends key to specific process)
curl -X POST http://127.0.0.1:7676/key \
  -H "Content-Type: application/json" \
  -d '{"key": "return", "pid": 1234}'

# Background mode: accessibility action on specific element
curl -X POST http://127.0.0.1:7676/key \
  -H "Content-Type: application/json" \
  -d '{"key": "return", "path": {"pid": 1234, "path": [0, 0, 1, 3]}}'
```

Available keys:
- Letters: `a`-`z`
- Numbers: `0`-`9`
- Function keys: `f1`-`f12`
- Special: `return`, `tab`, `space`, `delete`, `escape`, `up`, `down`, `left`, `right`, `home`, `end`, `pageup`, `pagedown`

Modifiers: `"cmd"`, `"ctrl"`, `"alt"`, `"shift"`, `"fn"`

Background mode parameters:
- `pid`: Target process ID for PID-targeted CGEvent (works with any key)
- `path`: Direct element path for accessibility action mapping (limited keys: `return`/`enter` -> confirm, `escape` -> cancel, `space` -> press)

### POST /scroll

Scrolls at a position. Supports background mode via PID targeting or element path.

```bash
# Scroll down (frontmost app)
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

# Background mode: PID-targeted scroll
curl -X POST http://127.0.0.1:7676/scroll \
  -H "Content-Type: application/json" \
  -d '{"x": 500, "y": 300, "delta_y": -100, "pid": 1234}'

# Background mode: scroll at element's center
curl -X POST http://127.0.0.1:7676/scroll \
  -H "Content-Type: application/json" \
  -d '{"delta_y": -100, "path": {"pid": 1234, "path": [0, 0, 2]}}'
```

Parameters:
- `x`: X coordinate (required unless `path` is provided)
- `y`: Y coordinate (required unless `path` is provided)
- `delta_x`: Horizontal scroll amount (negative = right)
- `delta_y`: Vertical scroll amount (negative = down)

Background mode parameters:
- `pid`: Target process ID for PID-targeted scroll
- `path`: Direct element path - scrolls at the element's center coordinates

## Accessibility API

The accessibility API provides semantic access to UI elements using macOS Accessibility (AXUIElement). This is more reliable than coordinate-based clicking because you can find and interact with elements by their role, title, or label.

### GET /accessibility/tree

Get the UI element hierarchy for an application. Supports two output formats:
- **tree** (default): Nested hierarchy with all details
- **compact**: Flattened list with only essential info (easier to scan)

```bash
# Get tree for frontmost app (default depth: 5)
curl "http://127.0.0.1:7676/accessibility/tree"

# Get tree for specific app with custom depth
curl "http://127.0.0.1:7676/accessibility/tree?pid=12345&maxDepth=3"

# Get COMPACT format (recommended for finding elements quickly)
curl "http://127.0.0.1:7676/accessibility/tree?format=compact&maxDepth=3"

# Compact format without actions (even smaller response)
curl "http://127.0.0.1:7676/accessibility/tree?format=compact&includeActions=false"
```

Parameters:
- `pid`: Process ID (uses frontmost app if not specified)
- `maxDepth`: Maximum tree depth (default: 5, max: 10)
- `format`: `"tree"` (default) or `"compact"` (flattened list)
- `includeActions`: Include action list in compact format (default: true)

Response (format=tree):
```json
{
  "success": true,
  "app": {
    "name": "Calculator",
    "bundle_identifier": "com.apple.calculator",
    "process_identifier": 12345
  },
  "tree": {
    "path": {"pid": 12345, "path": []},
    "role": "AXApplication",
    "title": "Calculator",
    "children": [
      {
        "path": {"pid": 12345, "path": [0]},
        "role": "AXWindow",
        "title": "Calculator",
        "children": [...]
      }
    ]
  }
}
```

Response (format=compact):
```json
{
  "success": true,
  "app": {
    "name": "Calculator",
    "process_identifier": 12345
  },
  "count": 25,
  "elements": [
    {"path": {"pid": 12345, "path": []}, "role": "AXApplication", "title": "Calculator", "depth": 0},
    {"path": {"pid": 12345, "path": [0]}, "role": "AXWindow", "title": "Calculator", "depth": 1},
    {"path": {"pid": 12345, "path": [0,0,0,6]}, "role": "AXButton", "label": "7", "frame": {"x": 424, "y": 721, "width": 48, "height": 48}, "actions": ["AXPress"], "depth": 4},
    {"path": {"pid": 12345, "path": [0,0,0,7]}, "role": "AXButton", "label": "8", "frame": {"x": 480, "y": 721, "width": 48, "height": 48}, "actions": ["AXPress"], "depth": 4}
  ]
}
```

The compact format:
- Returns a flat list instead of nested tree
- Only includes elements with text (title/label) or meaningful interactive roles
- Each element includes `depth` for understanding hierarchy
- Much easier to scan for finding specific elements

### GET /accessibility/elements

Find elements matching search criteria. At least one search parameter is required.

```bash
# Find all buttons
curl "http://127.0.0.1:7676/accessibility/elements?role=AXButton"

# Find button by exact title
curl "http://127.0.0.1:7676/accessibility/elements?role=AXButton&title=Submit"

# Find buttons containing "Save" in title
curl "http://127.0.0.1:7676/accessibility/elements?titleContains=Save"

# Find by label (accessibility description)
curl "http://127.0.0.1:7676/accessibility/elements?labelContains=7"

# Find text fields
curl "http://127.0.0.1:7676/accessibility/elements?role=AXTextField"

# Find in specific app
curl "http://127.0.0.1:7676/accessibility/elements?role=AXButton&pid=12345"
```

Parameters:
- `pid`: Process ID (uses frontmost app if not specified)
- `role`: Filter by role (e.g., `AXButton`, `AXTextField`, `AXStaticText`)
- `title`: Filter by exact title match
- `titleContains`: Filter by title containing string (case-insensitive)
- `labelContains`: Filter by label containing string (case-insensitive)
- `valueContains`: Filter by value containing string (case-insensitive)
- `maxResults`: Maximum results (default: 50)

Response:
```json
{
  "success": true,
  "app": {
    "name": "Calculator",
    "bundle_identifier": "com.apple.calculator",
    "process_identifier": 12345
  },
  "count": 1,
  "elements": [
    {
      "path": {"pid": 12345, "path": [0, 0, 0, 0, 0, 6]},
      "role": "AXButton",
      "label": "7",
      "frame": {"x": 424, "y": 721, "width": 48, "height": 48},
      "is_enabled": true,
      "is_focused": false,
      "actions": ["AXPress"]
    }
  ]
}
```

Common roles:
- `AXButton` - Buttons
- `AXTextField` - Text inputs
- `AXTextArea` - Multi-line text
- `AXCheckBox` - Checkboxes
- `AXRadioButton` - Radio buttons
- `AXPopUpButton` - Dropdowns
- `AXMenuItem` - Menu items
- `AXStaticText` - Labels/text
- `AXLink` - Links
- `AXWindow` - Windows

### GET /accessibility/focused

Get the currently focused UI element.

```bash
# Get focused element in frontmost app
curl "http://127.0.0.1:7676/accessibility/focused"

# Get focused element in specific app
curl "http://127.0.0.1:7676/accessibility/focused?pid=12345"
```

Response:
```json
{
  "success": true,
  "app": {
    "name": "TextEdit",
    "process_identifier": 12345
  },
  "element": {
    "path": {"pid": 12345, "path": [0, 0, 1, 0]},
    "role": "AXTextArea",
    "is_focused": true,
    "actions": ["AXShowMenu"]
  }
}
```

### POST /accessibility/action

Perform an action on a UI element identified by its path.

```bash
# Press a button (click)
curl -X POST "http://127.0.0.1:7676/accessibility/action" \
  -H "Content-Type: application/json" \
  -d '{"path": {"pid": 12345, "path": [0, 0, 0, 0, 0, 6]}, "action": "press"}'

# Set text field value
curl -X POST "http://127.0.0.1:7676/accessibility/action" \
  -H "Content-Type: application/json" \
  -d '{"path": {"pid": 12345, "path": [0, 0, 1]}, "action": "setValue", "value": "Hello"}'

# Focus an element
curl -X POST "http://127.0.0.1:7676/accessibility/action" \
  -H "Content-Type: application/json" \
  -d '{"path": {"pid": 12345, "path": [0, 0, 1]}, "action": "focus"}'
```

Parameters:
- `path` (required): Element path from find_elements or get_ui_tree
  - `pid`: Process ID
  - `path`: Array of child indices from app root
- `action` (required): Action to perform
- `value`: Value for `setValue` action

Available actions:
- `press` - Click/activate the element (like pressing a button)
- `setValue` - Set the element's value (for text fields)
- `focus` - Focus the element
- `confirm` - Confirm action (for dialogs)
- `cancel` - Cancel action (for dialogs)
- `increment` - Increment value (for steppers/sliders)
- `decrement` - Decrement value (for steppers/sliders)
- `showMenu` - Show context menu
- `pick` - Pick/select item

Response:
```json
{
  "success": true,
  "action": "press"
}
```

## Menu API

Access and trigger application menu items directly without keyboard shortcuts.

### GET /menu

Get the menu structure for an application.

```bash
# Get menus for Finder
curl "http://127.0.0.1:7676/menu?app=Finder"

# Get menus for Safari
curl "http://127.0.0.1:7676/menu?app=Safari"
```

Parameters:
- `app` (required): Application name (case-insensitive, partial match supported)

Response:
```json
{
  "success": true,
  "menus": [
    {
      "title": "Apple",
      "is_enabled": true,
      "has_submenu": true,
      "children": [
        {"title": "About This Mac", "is_enabled": true, "has_submenu": false, "shortcut": null},
        {"title": "System Settings...", "is_enabled": true, "has_submenu": false, "shortcut": null}
      ]
    },
    {
      "title": "File",
      "is_enabled": true,
      "has_submenu": true,
      "children": [
        {"title": "New Window", "is_enabled": true, "has_submenu": false, "shortcut": "Cmd+N"},
        {"title": "New Tab", "is_enabled": true, "has_submenu": false, "shortcut": "Cmd+T"},
        {"title": "Close Window", "is_enabled": true, "has_submenu": false, "shortcut": "Cmd+W"}
      ]
    }
  ]
}
```

### POST /menu

Trigger a menu item by its path. Supports background mode to avoid bringing the app to the foreground.

```bash
# Open a new Finder window
curl -X POST http://127.0.0.1:7676/menu \
  -H "Content-Type: application/json" \
  -d '{"app": "Finder", "path": ["File", "New Window"]}'

# Open Safari preferences
curl -X POST http://127.0.0.1:7676/menu \
  -H "Content-Type: application/json" \
  -d '{"app": "Safari", "path": ["Safari", "Settings..."]}'

# Toggle hidden files in Finder (View menu)
curl -X POST http://127.0.0.1:7676/menu \
  -H "Content-Type: application/json" \
  -d '{"app": "Finder", "path": ["View", "Show Hidden Files"]}'

# Background mode: trigger menu without bringing app to front
curl -X POST http://127.0.0.1:7676/menu \
  -H "Content-Type: application/json" \
  -d '{"app": "TextEdit", "path": ["Edit", "Select All"], "background": true}'
```

Parameters:
- `app` (required): Application name
- `path` (required): Array of menu item titles from top-level menu to target item
- `background`: If `true`, skip activating the app (it stays in the background). Note: some apps don't expose menus to accessibility when not frontmost.

Response:
```json
{
  "success": true
}
```

Error response:
```json
{
  "success": false,
  "error": "Menu item not found: File > NonExistent"
}
```

## Background Automation

Geisterhand supports automating apps without bringing them to the foreground. This lets users continue working while automation runs in the background.

### How It Works

Several endpoints accept optional `pid`, `path`, and `background` parameters. When provided, they use accessibility APIs or PID-targeted CGEvents instead of global events, allowing interaction with background apps.

| Endpoint | Background Mode | How |
|----------|----------------|-----|
| `/type` | `pid` + element query or `path` | Uses accessibility `setValue` to set text field content directly |
| `/key` | `pid` | PID-targeted CGEvent sent to specific process |
| `/key` | `path` | Maps key to accessibility action (return->confirm, escape->cancel, space->press) |
| `/scroll` | `pid` | PID-targeted scroll CGEvent |
| `/scroll` | `path` | Scrolls at element's center using PID-targeted CGEvent |
| `/menu` | `background: true` | Triggers menu via accessibility without activating the app |
| `/click/element` | `use_accessibility_action: true` | Clicks via AX press action (already supported) |
| `/screenshot` | `app=X` | Captures window even when off-screen/behind other windows |

### Background Automation Example

```bash
# Get TextEdit's PID
PID=$(pgrep TextEdit)

# Type into a text field without bringing TextEdit to front
curl -X POST http://127.0.0.1:7676/type \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"Hello from background\", \"pid\": $PID, \"role\": \"AXTextArea\"}"

# Press Enter targeted at TextEdit
curl -X POST http://127.0.0.1:7676/key \
  -H "Content-Type: application/json" \
  -d "{\"key\": \"return\", \"pid\": $PID}"

# Trigger menu without activating app
curl -X POST http://127.0.0.1:7676/menu \
  -H "Content-Type: application/json" \
  -d "{\"app\": \"TextEdit\", \"path\": [\"Edit\", \"Select All\"], \"background\": true}"

# Screenshot of TextEdit even when behind other windows
curl "http://127.0.0.1:7676/screenshot?app=TextEdit&format=base64"
```

### Limitations

- **`/type` background mode** uses `setValue` which replaces the entire field value atomically (no character-by-character typing, `delay_ms` has no effect)
- **`/key` with `path`** only supports a few keys mapped to accessibility actions: `return`/`enter`, `escape`, `space`. Use `pid` for arbitrary key presses.
- **PID-targeted CGEvents** (`pid` parameter on `/key` and `/scroll`) are less reliable than global events - some apps may not respond to them
- **`/menu` with `background: true`** may not work for apps that don't expose menus when not frontmost
- **For apps with poor accessibility support**, you may need coordinate-based interaction which requires the window to be visible

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

### Click a button by label (using Accessibility API)

```bash
# 1. Find the button by label
curl -s "http://127.0.0.1:7676/accessibility/elements?labelContains=Submit"
# Response includes: "path": {"pid": 12345, "path": [0, 1, 3, 2]}

# 2. Press the button
curl -X POST "http://127.0.0.1:7676/accessibility/action" \
  -H "Content-Type: application/json" \
  -d '{"path": {"pid": 12345, "path": [0, 1, 3, 2]}, "action": "press"}'
```

### Fill a form (using Accessibility API)

```bash
# 1. Find all text fields
curl -s "http://127.0.0.1:7676/accessibility/elements?role=AXTextField"

# 2. Set value in the first text field (e.g., username)
curl -X POST "http://127.0.0.1:7676/accessibility/action" \
  -H "Content-Type: application/json" \
  -d '{"path": {"pid": 12345, "path": [0, 0, 2, 1]}, "action": "setValue", "value": "myusername"}'

# 3. Find and click submit button
curl -s "http://127.0.0.1:7676/accessibility/elements?role=AXButton&titleContains=Submit"
curl -X POST "http://127.0.0.1:7676/accessibility/action" \
  -H "Content-Type: application/json" \
  -d '{"path": {"pid": 12345, "path": [0, 0, 2, 5]}, "action": "press"}'
```

### Use Calculator (using Accessibility API)

```bash
# Get Calculator's PID
PID=$(pgrep Calculator)

# Find and click "7" button
curl -s "http://127.0.0.1:7676/accessibility/elements?labelContains=7&pid=$PID"
# Returns path like [0, 0, 0, 0, 0, 6]

curl -X POST "http://127.0.0.1:7676/accessibility/action" \
  -H "Content-Type: application/json" \
  -d "{\"path\": {\"pid\": $PID, \"path\": [0, 0, 0, 0, 0, 6]}, \"action\": \"press\"}"

# Find and click "+" button
curl -s "http://127.0.0.1:7676/accessibility/elements?labelContains=Add&pid=$PID"
curl -X POST "http://127.0.0.1:7676/accessibility/action" \
  -H "Content-Type: application/json" \
  -d "{\"path\": {\"pid\": $PID, \"path\": [0, 0, 0, 0, 0, 5]}, \"action\": \"press\"}"

# Find and click "3" button, then "="
# ... continue pattern
```

### Complete login form (using new endpoints)

This example demonstrates the improved workflow with `/click/element` and `/wait`:

```bash
# 1. Wait for the login form to appear
curl -X POST http://127.0.0.1:7676/wait \
  -H "Content-Type: application/json" \
  -d '{"title_contains": "Username", "role": "AXTextField", "timeout_ms": 5000}'

# 2. Click the username field
curl -X POST http://127.0.0.1:7676/click/element \
  -H "Content-Type: application/json" \
  -d '{"title_contains": "Username", "role": "AXTextField"}'

# 3. Type username
curl -X POST http://127.0.0.1:7676/type \
  -H "Content-Type: application/json" \
  -d '{"text": "myuser@example.com"}'

# 4. Click password field
curl -X POST http://127.0.0.1:7676/click/element \
  -H "Content-Type: application/json" \
  -d '{"title_contains": "Password", "role": "AXSecureTextField"}'

# 5. Type password
curl -X POST http://127.0.0.1:7676/type \
  -H "Content-Type: application/json" \
  -d '{"text": "SecurePass123!"}'

# 6. Click Sign In button
curl -X POST http://127.0.0.1:7676/click/element \
  -H "Content-Type: application/json" \
  -d '{"title": "Sign In", "role": "AXButton"}'

# 7. Wait for login to complete (button disappears or success message appears)
curl -X POST http://127.0.0.1:7676/wait \
  -H "Content-Type: application/json" \
  -d '{"title": "Sign In", "condition": "not_exists", "timeout_ms": 10000}'
```

### Open preferences via menu

```bash
# Instead of Cmd+, which may not work in all apps:
curl -X POST http://127.0.0.1:7676/menu \
  -H "Content-Type: application/json" \
  -d '{"app": "Safari", "path": ["Safari", "Settings..."]}'

# Wait for preferences window
curl -X POST http://127.0.0.1:7676/wait \
  -H "Content-Type: application/json" \
  -d '{"title": "Settings", "role": "AXWindow", "timeout_ms": 3000}'

# Take a screenshot of just Safari's settings window
curl "http://127.0.0.1:7676/screenshot?app=Safari&format=base64"
```

## Tips for LLMs

1. **Always add delays** between actions (0.3-1 second) to let the UI respond
2. **Check /status first** to verify the server is running and has permissions
3. **Use /screenshot** to see the current screen state before/after actions
4. **Coordinates**: (0,0) is top-left corner of the main display
5. **Text input**: Use `/type` for text, `/key` for shortcuts and special keys
6. **All JSON uses snake_case** for field names

### Accessibility API Tips

7. **Prefer accessibility API over coordinates** - It's more reliable because:
   - Elements are found by semantic properties (role, label, title)
   - Actions are performed directly on elements, not at coordinates that might shift
   - No need to analyze screenshots to find click targets

8. **Workflow for clicking a button**:
   - First: `GET /accessibility/elements?role=AXButton&titleContains=...` to find it
   - Get the `path` from the response
   - Then: `POST /accessibility/action` with `{"path": ..., "action": "press"}`

9. **Use frame coordinates as fallback** - Each element includes a `frame` with `x`, `y`, `width`, `height`. Calculate center: `(x + width/2, y + height/2)` for coordinate-based clicking if action fails.

10. **Element paths are stable** within a session but may change if the UI structure changes (windows open/close, views update). Re-query if an action fails.

11. **Common patterns**:
    - Find buttons: `role=AXButton`
    - Find text inputs: `role=AXTextField` or `role=AXTextArea`
    - Find by visible text: `titleContains=...` or `labelContains=...`
    - Set input value: `action=setValue` with `value=...`
    - Click/press: `action=press`

12. **Get app PID** from `/status` response (`frontmost_app.process_identifier`) or use `pgrep AppName`

13. **Use `/wait` instead of sleep** - Instead of `sleep 1`, use `/wait` to intelligently wait for UI changes:
    ```bash
    # Bad: arbitrary delay
    sleep 2

    # Good: wait for specific element
    curl -X POST http://127.0.0.1:7676/wait \
      -H "Content-Type: application/json" \
      -d '{"title": "Done", "timeout_ms": 5000}'
    ```

14. **Use `/click/element` for semantic clicking** - Instead of finding coordinates manually:
    ```bash
    # Bad: multiple steps to click a button
    curl "http://127.0.0.1:7676/accessibility/elements?title=OK"
    # manually extract frame, calculate center, then click...

    # Good: single request
    curl -X POST http://127.0.0.1:7676/click/element \
      -d '{"title": "OK", "role": "AXButton"}'
    ```

15. **Use app-specific screenshots** - Capture just the target app window for clearer context:
    ```bash
    curl "http://127.0.0.1:7676/screenshot?app=Safari&format=base64"
    ```

16. **Use `/menu` for menu actions** - More reliable than keyboard shortcuts:
    ```bash
    curl -X POST http://127.0.0.1:7676/menu \
      -d '{"app": "Safari", "path": ["File", "New Window"]}'
    ```

17. **Use background mode for non-intrusive automation** - Add `pid` or `path` to `/type`, `/key`, `/scroll` to interact with apps without bringing them to front:
    ```bash
    # Type into a background app's text field
    curl -X POST http://127.0.0.1:7676/type \
      -d '{"text": "hello", "pid": 1234, "role": "AXTextField"}'

    # Send key to background app
    curl -X POST http://127.0.0.1:7676/key \
      -d '{"key": "return", "pid": 1234}'

    # Trigger menu without activating app
    curl -X POST http://127.0.0.1:7676/menu \
      -d '{"app": "Safari", "path": ["File", "New Tab"], "background": true}'
    ```

## Troubleshooting

### Special Characters in Text

The `/type` endpoint handles special characters via Unicode input. If you get errors:

1. **Ensure proper JSON escaping**: Special characters in JSON strings must be escaped:
   ```bash
   # Correct: quotes and backslashes escaped
   curl -X POST http://127.0.0.1:7676/type \
     -H "Content-Type: application/json" \
     -d '{"text": "Password123!"}'

   # If your text has quotes, escape them:
   curl -X POST http://127.0.0.1:7676/type \
     -H "Content-Type: application/json" \
     -d '{"text": "He said \"Hello\""}'

   # For backslashes:
   curl -X POST http://127.0.0.1:7676/type \
     -H "Content-Type: application/json" \
     -d '{"text": "C:\\Users\\Name"}'
   ```

2. **Common JSON escape sequences**:
   - `\"` - double quote
   - `\\` - backslash
   - `\n` - newline
   - `\t` - tab

3. **Characters that work without escaping**: `!@#$%^&*()-_=+[]{}|;':,.<>/?~`

### 400 Bad Request Errors

Usually indicates malformed JSON. Check:
- All strings are quoted
- No trailing commas
- Special characters are escaped
- Request body is valid JSON (use `jq` to validate: `echo '{"text":"test"}' | jq`)

### Element Not Found

1. **Check the PID**: Make sure you're searching in the right app
2. **Check frontmost app**: If no PID specified, searches frontmost app
3. **Use `/accessibility/tree?format=compact`** to see available elements
4. **Try `titleContains` instead of exact `title`** for partial matches
5. **Increase `maxDepth`** if element is deeply nested

### Action Failed

1. **Element path may have changed**: Re-query the element
2. **Element may be disabled**: Check `is_enabled` in element info
3. **Try `use_accessibility_action: true`** in `/click/element` for more reliable clicks
4. **Some apps don't fully support accessibility**: May need coordinate-based clicks

### Menu Not Found

1. **App must be running**: Check with `/status`
2. **App may need to be frontmost**: Geisterhand activates the app, but give it a moment
3. **Menu titles are case-sensitive in paths**: Use exact titles from `/menu?app=...` response
4. **Some menus are dynamic**: May only appear in certain states
