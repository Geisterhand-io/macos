import SwiftUI
import GeisterhandCore

@main
struct GeisterhandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

/// The menu bar icon label that shows permission/server status
struct MenuBarLabel: View {
    @StateObject private var statusMonitor = StatusMonitor.shared

    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(iconColor)
    }

    private var iconName: String {
        "hand.raised.fill"
    }

    private var iconColor: Color {
        switch statusMonitor.status {
        case .allGood:
            return .green
        case .partialPermissions:
            return .yellow
        case .error:
            return .red
        }
    }
}

/// Monitors the overall status of the app
@MainActor
class StatusMonitor: ObservableObject {
    static let shared = StatusMonitor()

    enum Status {
        case allGood
        case partialPermissions
        case error
    }

    @Published var status: Status = .partialPermissions
    @Published var accessibilityGranted: Bool = false
    @Published var screenRecordingGranted: Bool = false
    @Published var serverRunning: Bool = false

    private var timer: Timer?

    private init() {
        updateStatus()
        startMonitoring()
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatus()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func updateStatus() {
        let permissionManager = PermissionManager.shared

        accessibilityGranted = permissionManager.isAccessibilityGranted
        screenRecordingGranted = permissionManager.isScreenRecordingGranted
        serverRunning = ServerManager.shared.isRunning

        if accessibilityGranted && screenRecordingGranted && serverRunning {
            status = .allGood
        } else if !serverRunning {
            status = .error
        } else {
            status = .partialPermissions
        }
    }
}
