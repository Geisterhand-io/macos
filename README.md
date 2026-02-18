# Geisterhand

macOS screen automation tool with HTTP API and CLI. Automate any Mac app — click buttons, type text, navigate menus, and capture screenshots.

## Install

```bash
brew install --cask geisterhand-io/tap/geisterhand
```

This installs the menu bar app and the `geisterhand` CLI. Or [download the DMG](https://github.com/Geisterhand-io/macos/releases/latest) directly.

<details>
<summary>Other install methods</summary>

**CLI only (no menu bar app):**
```bash
brew install geisterhand-io/tap/geisterhand
```

**Build from source:**
```bash
git clone https://github.com/Geisterhand-io/macos.git && cd macos
swift build -c release
# Binaries: .build/release/geisterhand (CLI), .build/release/GeisterhandApp (menu bar app)
```
</details>

## Quick Start

**1. Grant permissions** — Launch the app once and grant Accessibility and Screen Recording in System Settings > Privacy & Security.

**2. Run:**

```bash
geisterhand run Calculator
# {"port":49152,"pid":12345,"app":"Calculator","host":"127.0.0.1"}
```

**3. Automate:**

```bash
# See what's on screen
curl http://127.0.0.1:49152/accessibility/tree?format=compact

# Click a button
curl -X POST http://127.0.0.1:49152/click/element \
  -H "Content-Type: application/json" \
  -d '{"title": "7", "role": "AXButton"}'

# Take a screenshot
curl http://127.0.0.1:49152/screenshot --output screen.png
```

## `geisterhand run`

The primary way to use Geisterhand. Launches (or attaches to) an app and starts an HTTP server scoped to it:

```bash
geisterhand run Safari                    # by app name
geisterhand run /Applications/Xcode.app   # by path
geisterhand run com.apple.TextEdit        # by bundle identifier
geisterhand run Calculator --port 7676    # pin a specific port
```

The server auto-selects a free port, scopes all requests to the target app's PID, and exits when the app quits. Connection details are printed as a JSON line on stdout.

## HTTP API

All endpoints accept and return JSON with `snake_case` field names.

| Method | Path | Description |
|--------|------|-------------|
| GET | `/status` | System info, permissions, frontmost app |
| GET | `/screenshot` | Capture screen or app window (`?app=Name`) |
| POST | `/click` | Click at coordinates |
| POST | `/click/element` | Click element by title/role/label |
| POST | `/type` | Type text |
| POST | `/key` | Press key with modifiers |
| POST | `/scroll` | Scroll at position |
| POST | `/wait` | Wait for element to appear/disappear/become enabled |
| GET | `/accessibility/tree` | Get UI element hierarchy (`?format=compact`) |
| GET | `/accessibility/elements` | Find elements by role/title/label |
| GET | `/accessibility/focused` | Get focused element |
| POST | `/accessibility/action` | Perform action on element (press, setValue, focus, ...) |
| GET | `/menu` | Get application menu structure |
| POST | `/menu` | Trigger menu item |

All input endpoints (`/type`, `/key`, `/scroll`, `/click/element`, `/menu`) support **background mode** — pass `pid`, `path`, or `use_accessibility_action` to automate apps without bringing them to the foreground.

## CLI

```bash
geisterhand status                          # check permissions
geisterhand screenshot -o screenshot.png    # capture screen
geisterhand click 100 200                   # click at coordinates
geisterhand click 100 200 --cmd --shift     # click with modifiers
geisterhand type "Hello World"              # type text
geisterhand key s --cmd                     # press Cmd+S
geisterhand scroll 500 300 --delta -100     # scroll up
geisterhand server --port 7676              # start HTTP server
```

## Documentation

- **[Testing Guide](TESTING_WITH_GEISTERHAND.md)** — Full reference for automating apps with Geisterhand. Includes a `CLAUDE.md` snippet you can drop into any project, 10 recipes (forms, menus, dialogs, screenshots, ...), best practices, and troubleshooting. Also serves as context for LLMs.
- **[API Guide](LLM_API_GUIDE.md)** — Complete endpoint reference with curl examples, optimized for LLM consumption.

## Using with Claude

Add Geisterhand as an MCP server for Claude Code or Claude Desktop:

```bash
# Claude Code
claude mcp add-json geisterhand \
  '{"type":"stdio","command":"npx","args":["geisterhand-mcp"]}' \
  --scope user
```

<details>
<summary>Claude Desktop</summary>

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "geisterhand": {
      "command": "npx",
      "args": ["geisterhand-mcp"]
    }
  }
}
```
</details>

Or use `geisterhand run` directly — add the [Testing Guide](TESTING_WITH_GEISTERHAND.md) snippet to your project's `CLAUDE.md` and Claude will use the HTTP API via curl.

## Menu Bar App

The menu bar app runs the server persistently and manages permissions:
- Green icon: all permissions granted, server running
- Yellow icon: missing some permissions
- Red icon: server not running

## Requirements

- macOS 14.0 (Sonoma) or later
- Accessibility permission (keyboard/mouse control)
- Screen Recording permission (screenshots)

## License

MIT — Skelpo GmbH
