import AppKit
import GeisterhandCore

/// App delegate handling lifecycle events and server management
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request permissions on launch
        requestPermissions()

        // Start the HTTP server
        startServer()

        // Update status after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Task { @MainActor in
                StatusMonitor.shared.updateStatus()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop the server on quit
        ServerManager.shared.stopServer()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running even when all windows are closed (menu bar app)
        return false
    }

    // MARK: - Private Methods

    private func requestPermissions() {
        let permissionManager = PermissionManager.shared

        // Request accessibility permission (shows system dialog if needed)
        if !permissionManager.isAccessibilityGranted {
            permissionManager.requestAccessibilityPermission()
        }

        // Check screen recording permission (triggers dialog on first access)
        Task {
            _ = await permissionManager.checkScreenRecordingPermission()
            await MainActor.run {
                StatusMonitor.shared.updateStatus()
            }
        }
    }

    private func startServer() {
        ServerManager.shared.startServer()
    }
}
