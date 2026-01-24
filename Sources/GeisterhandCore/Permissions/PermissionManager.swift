import Foundation
import AppKit
@preconcurrency import ScreenCaptureKit

/// Manages accessibility and screen recording permissions
public final class PermissionManager: @unchecked Sendable {
    public static let shared = PermissionManager()

    private init() {}

    // MARK: - Accessibility Permission

    /// Checks if accessibility permission is granted
    public var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Requests accessibility permission with a system prompt
    /// - Returns: Whether the permission is currently granted
    @discardableResult
    public func requestAccessibilityPermission() -> Bool {
        // Use string directly to avoid Swift 6 concurrency issues with global C variables
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Screen Recording Permission

    /// Checks if screen recording permission is granted
    /// Note: This triggers permission dialog if not already granted
    public func checkScreenRecordingPermission() async -> Bool {
        do {
            // Attempting to get shareable content will trigger the permission dialog
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            // If we get an error, permission is likely not granted
            return false
        }
    }

    /// Synchronous check for screen recording - uses cached state or optimistic check
    public var isScreenRecordingGranted: Bool {
        // Use CGWindowListCopyWindowInfo as a quick check
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        // If we can see window names, we have permission
        return windowList?.first?[kCGWindowName as String] != nil || (windowList?.isEmpty == false)
    }

    // MARK: - Combined Status

    /// Returns the current permission status
    public var permissionStatus: PermissionStatus {
        PermissionStatus(
            accessibility: isAccessibilityGranted,
            screenRecording: isScreenRecordingGranted
        )
    }

    /// Checks if all required permissions are granted
    public var allPermissionsGranted: Bool {
        isAccessibilityGranted && isScreenRecordingGranted
    }

    // MARK: - Open System Preferences

    /// Opens System Preferences to the Accessibility pane
    public func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Opens System Preferences to the Screen Recording pane
    public func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    /// Opens System Preferences to the Privacy & Security pane
    public func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
        NSWorkspace.shared.open(url)
    }
}
