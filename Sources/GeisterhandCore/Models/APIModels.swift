import Foundation

// MARK: - Status Response

public struct StatusResponse: Codable, Sendable {
    public let status: String
    public let version: String
    public let serverRunning: Bool
    public let permissions: PermissionStatus
    public let frontmostApp: AppInfo?
    public let screenSize: ScreenSize

    public init(
        status: String,
        version: String,
        serverRunning: Bool,
        permissions: PermissionStatus,
        frontmostApp: AppInfo?,
        screenSize: ScreenSize
    ) {
        self.status = status
        self.version = version
        self.serverRunning = serverRunning
        self.permissions = permissions
        self.frontmostApp = frontmostApp
        self.screenSize = screenSize
    }
}

public struct PermissionStatus: Codable, Sendable {
    public let accessibility: Bool
    public let screenRecording: Bool

    public init(accessibility: Bool, screenRecording: Bool) {
        self.accessibility = accessibility
        self.screenRecording = screenRecording
    }
}

public struct AppInfo: Codable, Sendable {
    public let name: String
    public let bundleIdentifier: String?
    public let processIdentifier: Int32

    public init(name: String, bundleIdentifier: String?, processIdentifier: Int32) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
    }
}

public struct ScreenSize: Codable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

// MARK: - Screenshot

public struct ScreenshotRequest: Codable, Sendable {
    public let format: String?
    public let displayId: UInt32?

    public init(format: String? = nil, displayId: UInt32? = nil) {
        self.format = format
        self.displayId = displayId
    }
}

public struct ScreenshotResponse: Codable, Sendable {
    public let success: Bool
    public let format: String
    public let width: Int
    public let height: Int
    public let data: String?
    public let error: String?
    /// Window information when capturing a specific window
    public let window: WindowInfo?

    public init(success: Bool, format: String, width: Int, height: Int, data: String? = nil, error: String? = nil, window: WindowInfo? = nil) {
        self.success = success
        self.format = format
        self.width = width
        self.height = height
        self.data = data
        self.error = error
        self.window = window
    }
}

// MARK: - Click

public struct ClickRequest: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let button: MouseButton?
    public let clickCount: Int?
    public let modifiers: [KeyModifier]?

    public init(x: Double, y: Double, button: MouseButton? = nil, clickCount: Int? = nil, modifiers: [KeyModifier]? = nil) {
        self.x = x
        self.y = y
        self.button = button
        self.clickCount = clickCount
        self.modifiers = modifiers
    }
}

public enum MouseButton: String, Codable, Sendable {
    case left
    case right
    case center
}

public struct ClickResponse: Codable, Sendable {
    public let success: Bool
    public let x: Double
    public let y: Double
    public let button: String
    public let error: String?

    public init(success: Bool, x: Double, y: Double, button: String, error: String? = nil) {
        self.success = success
        self.x = x
        self.y = y
        self.button = button
        self.error = error
    }
}

// MARK: - Type

public struct TypeRequest: Codable, Sendable {
    public let text: String
    public let delayMs: Int?
    /// Target process ID for background mode (uses accessibility setValue)
    public let pid: Int32?
    /// Direct element path for background mode
    public let path: ElementPath?
    /// Accessibility role to match (e.g., "AXTextField")
    public let role: String?
    /// Element title (exact match)
    public let title: String?
    /// Element title substring (case-insensitive)
    public let titleContains: String?

    public init(text: String, delayMs: Int? = nil, pid: Int32? = nil, path: ElementPath? = nil, role: String? = nil, title: String? = nil, titleContains: String? = nil) {
        self.text = text
        self.delayMs = delayMs
        self.pid = pid
        self.path = path
        self.role = role
        self.title = title
        self.titleContains = titleContains
    }
}

public struct TypeResponse: Codable, Sendable {
    public let success: Bool
    public let charactersTyped: Int
    public let error: String?

    public init(success: Bool, charactersTyped: Int, error: String? = nil) {
        self.success = success
        self.charactersTyped = charactersTyped
        self.error = error
    }
}

// MARK: - Key

public struct KeyRequest: Codable, Sendable {
    public let key: String
    public let modifiers: [KeyModifier]?
    /// Target process ID for PID-targeted CGEvent
    public let pid: Int32?
    /// Direct element path for accessibility action mapping
    public let path: ElementPath?

    public init(key: String, modifiers: [KeyModifier]? = nil, pid: Int32? = nil, path: ElementPath? = nil) {
        self.key = key
        self.modifiers = modifiers
        self.pid = pid
        self.path = path
    }
}

public enum KeyModifier: String, Codable, Sendable {
    case cmd
    case command
    case ctrl
    case control
    case alt
    case option
    case shift
    case fn
    case function
}

public struct KeyResponse: Codable, Sendable {
    public let success: Bool
    public let key: String
    public let modifiers: [String]
    public let error: String?

    public init(success: Bool, key: String, modifiers: [String], error: String? = nil) {
        self.success = success
        self.key = key
        self.modifiers = modifiers
        self.error = error
    }
}

// MARK: - Scroll

public struct ScrollRequest: Codable, Sendable {
    public let x: Double?
    public let y: Double?
    public let deltaX: Double?
    public let deltaY: Double?
    /// Target process ID for PID-targeted scroll
    public let pid: Int32?
    /// Direct element path - scroll at the element's center
    public let path: ElementPath?

    public init(x: Double? = nil, y: Double? = nil, deltaX: Double? = nil, deltaY: Double? = nil, pid: Int32? = nil, path: ElementPath? = nil) {
        self.x = x
        self.y = y
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.pid = pid
        self.path = path
    }
}

public struct ScrollResponse: Codable, Sendable {
    public let success: Bool
    public let x: Double
    public let y: Double
    public let deltaX: Double
    public let deltaY: Double
    public let error: String?

    public init(success: Bool, x: Double, y: Double, deltaX: Double, deltaY: Double, error: String? = nil) {
        self.success = success
        self.x = x
        self.y = y
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.error = error
    }
}

// MARK: - Element Click

public struct ElementClickRequest: Codable, Sendable {
    /// Element title to match (exact match)
    public let title: String?
    /// Element title substring to match (case-insensitive)
    public let titleContains: String?
    /// Accessibility role to match (e.g., "AXButton")
    public let role: String?
    /// Process ID of the target application (uses frontmost if not specified)
    public let pid: Int32?
    /// Element label to match (accessibility description)
    public let label: String?
    /// Whether to use AX press action instead of mouse click (default: false)
    public let useAccessibilityAction: Bool?
    /// Mouse button to use if not using accessibility action (default: left)
    public let button: MouseButton?

    public init(
        title: String? = nil,
        titleContains: String? = nil,
        role: String? = nil,
        pid: Int32? = nil,
        label: String? = nil,
        useAccessibilityAction: Bool? = nil,
        button: MouseButton? = nil
    ) {
        self.title = title
        self.titleContains = titleContains
        self.role = role
        self.pid = pid
        self.label = label
        self.useAccessibilityAction = useAccessibilityAction
        self.button = button
    }
}

public struct ElementClickResponse: Codable, Sendable {
    public let success: Bool
    /// The element that was clicked
    public let element: ClickedElementInfo?
    /// The click coordinates (if mouse click was used)
    public let clickedAt: ClickCoordinates?
    /// Error message if unsuccessful
    public let error: String?

    public init(success: Bool, element: ClickedElementInfo? = nil, clickedAt: ClickCoordinates? = nil, error: String? = nil) {
        self.success = success
        self.element = element
        self.clickedAt = clickedAt
        self.error = error
    }
}

public struct ClickedElementInfo: Codable, Sendable {
    public let role: String
    public let title: String?
    public let label: String?
    public let frame: ElementFrameInfo?

    public init(role: String, title: String?, label: String?, frame: ElementFrameInfo?) {
        self.role = role
        self.title = title
        self.label = label
        self.frame = frame
    }
}

public struct ElementFrameInfo: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct ClickCoordinates: Codable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// MARK: - Wait

public struct WaitRequest: Codable, Sendable {
    /// Element title to match (exact match)
    public let title: String?
    /// Element title substring to match (case-insensitive)
    public let titleContains: String?
    /// Accessibility role to match (e.g., "AXButton")
    public let role: String?
    /// Process ID of the target application (uses frontmost if not specified)
    public let pid: Int32?
    /// Element label to match (accessibility description)
    public let label: String?
    /// Timeout in milliseconds (default: 5000)
    public let timeoutMs: Int?
    /// Poll interval in milliseconds (default: 100)
    public let pollIntervalMs: Int?
    /// Condition to wait for (default: exists)
    public let condition: WaitCondition?

    public init(
        title: String? = nil,
        titleContains: String? = nil,
        role: String? = nil,
        pid: Int32? = nil,
        label: String? = nil,
        timeoutMs: Int? = nil,
        pollIntervalMs: Int? = nil,
        condition: WaitCondition? = nil
    ) {
        self.title = title
        self.titleContains = titleContains
        self.role = role
        self.pid = pid
        self.label = label
        self.timeoutMs = timeoutMs
        self.pollIntervalMs = pollIntervalMs
        self.condition = condition
    }
}

public enum WaitCondition: String, Codable, Sendable {
    case exists = "exists"
    case notExists = "not_exists"
    case enabled = "enabled"
    case focused = "focused"
}

public struct WaitResponse: Codable, Sendable {
    public let success: Bool
    /// Whether the condition was met
    public let conditionMet: Bool
    /// The matched element (if condition was met and element exists)
    public let element: ClickedElementInfo?
    /// Time waited in milliseconds
    public let waitedMs: Int
    /// Error message if unsuccessful
    public let error: String?

    public init(success: Bool, conditionMet: Bool, element: ClickedElementInfo? = nil, waitedMs: Int, error: String? = nil) {
        self.success = success
        self.conditionMet = conditionMet
        self.element = element
        self.waitedMs = waitedMs
        self.error = error
    }
}

// MARK: - Menu

public struct MenuGetRequest: Codable, Sendable {
    /// Application name (required)
    public let app: String

    public init(app: String) {
        self.app = app
    }
}

public struct MenuTriggerRequest: Codable, Sendable {
    /// Application name (required)
    public let app: String
    /// Menu path to trigger (e.g., ["File", "New Window"])
    public let path: [String]
    /// If true, skip app.activate() to avoid bringing the app to the foreground
    public let background: Bool?

    public init(app: String, path: [String], background: Bool? = nil) {
        self.app = app
        self.path = path
        self.background = background
    }
}

public struct MenuResponse: Codable, Sendable {
    public let success: Bool
    /// The menu structure (for GET)
    public let menus: [MenuItemInfo]?
    /// Error message if unsuccessful
    public let error: String?

    public init(success: Bool, menus: [MenuItemInfo]? = nil, error: String? = nil) {
        self.success = success
        self.menus = menus
        self.error = error
    }
}

public struct MenuItemInfo: Codable, Sendable {
    public let title: String
    public let isEnabled: Bool
    public let hasSubmenu: Bool
    public let shortcut: String?
    public let children: [MenuItemInfo]?

    public init(title: String, isEnabled: Bool, hasSubmenu: Bool, shortcut: String?, children: [MenuItemInfo]?) {
        self.title = title
        self.isEnabled = isEnabled
        self.hasSubmenu = hasSubmenu
        self.shortcut = shortcut
        self.children = children
    }
}

// MARK: - Error Response

public struct ErrorResponse: Codable, Sendable {
    public let error: String
    public let code: Int

    public init(error: String, code: Int) {
        self.error = error
        self.code = code
    }
}
