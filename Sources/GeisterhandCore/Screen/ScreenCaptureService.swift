import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit

/// Service for capturing screen content using ScreenCaptureKit
public actor ScreenCaptureService {
    public static let shared = ScreenCaptureService()

    private let encoder = ImageEncoder()

    private init() {}

    /// Captures the entire screen or a specific display
    /// - Parameter displayId: Optional display ID (uses main display if nil)
    /// - Returns: The captured CGImage
    /// - Throws: ScreenCaptureError if capture fails
    public func captureScreen(displayId: CGDirectDisplayID? = nil) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Find the requested display or use main display
        let targetDisplayId = displayId ?? CGMainDisplayID()
        guard let display = content.displays.first(where: { $0.displayID == targetDisplayId })
                ?? content.displays.first else {
            throw ScreenCaptureError.noDisplayFound
        }

        // Configure capture
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()

        // Set resolution to match display
        config.width = display.width
        config.height = display.height

        // High quality capture
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.captureResolution = .best

        // Capture single frame
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        return image
    }

    /// Captures a specific window
    /// - Parameter windowId: The window ID to capture
    /// - Returns: The captured CGImage
    /// - Throws: ScreenCaptureError if capture fails
    public func captureWindow(windowId: CGWindowID) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let window = content.windows.first(where: { $0.windowID == windowId }) else {
            throw ScreenCaptureError.windowNotFound(windowId)
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()

        // Match window size
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.captureResolution = .best

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        return image
    }

    /// Captures the screen and returns PNG data
    /// - Parameter displayId: Optional display ID
    /// - Returns: PNG image data
    public func captureScreenAsPNG(displayId: CGDirectDisplayID? = nil) async throws -> Data {
        let image = try await captureScreen(displayId: displayId)
        return try encoder.encodePNG(image)
    }

    /// Captures the screen and returns base64-encoded PNG
    /// - Parameter displayId: Optional display ID
    /// - Returns: Base64-encoded PNG string
    public func captureScreenAsBase64(displayId: CGDirectDisplayID? = nil) async throws -> String {
        let pngData = try await captureScreenAsPNG(displayId: displayId)
        return encoder.encodeBase64(pngData)
    }

    /// Captures the screen and saves to a file
    /// - Parameters:
    ///   - path: File path to save to
    ///   - displayId: Optional display ID
    public func captureScreenToFile(path: String, displayId: CGDirectDisplayID? = nil) async throws {
        let pngData = try await captureScreenAsPNG(displayId: displayId)
        try encoder.saveToFile(pngData, path: path)
    }

    /// Gets the size of the main display
    /// - Returns: Screen size
    public func getMainDisplaySize() -> ScreenSize {
        let mainDisplay = CGMainDisplayID()
        let width = CGDisplayPixelsWide(mainDisplay)
        let height = CGDisplayPixelsHigh(mainDisplay)
        return ScreenSize(width: Double(width), height: Double(height))
    }

    /// Gets information about all available displays
    /// - Returns: Array of display information
    public func getAvailableDisplays() async throws -> [(id: CGDirectDisplayID, width: Int, height: Int)] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.displays.map { display in
            (id: display.displayID, width: display.width, height: display.height)
        }
    }

    /// Finds windows belonging to an application by name
    /// - Parameter appName: The application name to search for (case-insensitive partial match)
    /// - Returns: Array of window info with IDs, titles, and frames
    public func findWindowsByApp(appName: String) async throws -> [WindowInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        let matchingWindows = content.windows.filter { window in
            guard let owningAppName = window.owningApplication?.applicationName else { return false }
            return owningAppName.localizedCaseInsensitiveContains(appName)
        }

        return matchingWindows.map { window in
            WindowInfo(
                windowId: window.windowID,
                title: window.title,
                appName: window.owningApplication?.applicationName,
                bundleIdentifier: window.owningApplication?.bundleIdentifier,
                frame: WindowFrame(
                    x: Double(window.frame.origin.x),
                    y: Double(window.frame.origin.y),
                    width: Double(window.frame.width),
                    height: Double(window.frame.height)
                ),
                isOnScreen: window.isOnScreen
            )
        }
    }

    /// Captures a window by app name (uses the first matching window)
    /// - Parameter appName: The application name to capture
    /// - Returns: The captured CGImage and window info
    public func captureWindowByApp(appName: String) async throws -> (image: CGImage, windowInfo: WindowInfo) {
        let windows = try await findWindowsByApp(appName: appName)

        guard let window = windows.first(where: { $0.isOnScreen }) ?? windows.first else {
            throw ScreenCaptureError.windowNotFoundByName(appName)
        }

        let image = try await captureWindow(windowId: window.windowId)
        return (image, window)
    }

    /// Captures a window and returns PNG data with window info
    public func captureWindowAsPNG(windowId: CGWindowID) async throws -> (data: Data, width: Int, height: Int) {
        let image = try await captureWindow(windowId: windowId)
        let data = try encoder.encodePNG(image)
        return (data, image.width, image.height)
    }

    /// Captures a window by app name and returns PNG data
    public func captureWindowByAppAsPNG(appName: String) async throws -> (data: Data, windowInfo: WindowInfo) {
        let (image, windowInfo) = try await captureWindowByApp(appName: appName)
        let data = try encoder.encodePNG(image)
        return (data, windowInfo)
    }

    /// Captures a window and returns base64-encoded PNG
    public func captureWindowAsBase64(windowId: CGWindowID) async throws -> (base64: String, width: Int, height: Int) {
        let (data, width, height) = try await captureWindowAsPNG(windowId: windowId)
        return (encoder.encodeBase64(data), width, height)
    }

    /// Captures a window by app name and returns base64-encoded PNG
    public func captureWindowByAppAsBase64(appName: String) async throws -> (base64: String, windowInfo: WindowInfo) {
        let (data, windowInfo) = try await captureWindowByAppAsPNG(appName: appName)
        return (encoder.encodeBase64(data), windowInfo)
    }
}

// MARK: - Window Info

public struct WindowInfo: Codable, Sendable {
    public let windowId: UInt32
    public let title: String?
    public let appName: String?
    public let bundleIdentifier: String?
    public let frame: WindowFrame
    public let isOnScreen: Bool

    public init(windowId: UInt32, title: String?, appName: String?, bundleIdentifier: String?, frame: WindowFrame, isOnScreen: Bool) {
        self.windowId = windowId
        self.title = title
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.frame = frame
        self.isOnScreen = isOnScreen
    }
}

public struct WindowFrame: Codable, Sendable {
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

// MARK: - Error Types

public enum ScreenCaptureError: Error, LocalizedError {
    case noDisplayFound
    case windowNotFound(CGWindowID)
    case windowNotFoundByName(String)
    case captureFailed(String)
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for capture"
        case .windowNotFound(let id):
            return "Window not found: \(id)"
        case .windowNotFoundByName(let name):
            return "No window found for application: \(name)"
        case .captureFailed(let reason):
            return "Screen capture failed: \(reason)"
        case .permissionDenied:
            return "Screen recording permission denied"
        }
    }
}
