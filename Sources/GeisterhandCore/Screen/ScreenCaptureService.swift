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
}

// MARK: - Error Types

public enum ScreenCaptureError: Error, LocalizedError {
    case noDisplayFound
    case windowNotFound(CGWindowID)
    case captureFailed(String)
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for capture"
        case .windowNotFound(let id):
            return "Window not found: \(id)"
        case .captureFailed(let reason):
            return "Screen capture failed: \(reason)"
        case .permissionDenied:
            return "Screen recording permission denied"
        }
    }
}
