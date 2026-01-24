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

    public init(success: Bool, format: String, width: Int, height: Int, data: String? = nil, error: String? = nil) {
        self.success = success
        self.format = format
        self.width = width
        self.height = height
        self.data = data
        self.error = error
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

    public init(text: String, delayMs: Int? = nil) {
        self.text = text
        self.delayMs = delayMs
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

    public init(key: String, modifiers: [KeyModifier]? = nil) {
        self.key = key
        self.modifiers = modifiers
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
    public let x: Double
    public let y: Double
    public let deltaX: Double?
    public let deltaY: Double?

    public init(x: Double, y: Double, deltaX: Double? = nil, deltaY: Double? = nil) {
        self.x = x
        self.y = y
        self.deltaX = deltaX
        self.deltaY = deltaY
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

// MARK: - Error Response

public struct ErrorResponse: Codable, Sendable {
    public let error: String
    public let code: Int

    public init(error: String, code: Int) {
        self.error = error
        self.code = code
    }
}
