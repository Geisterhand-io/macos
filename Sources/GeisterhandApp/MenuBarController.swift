import SwiftUI
import GeisterhandCore

/// The main menu bar dropdown view
struct MenuBarView: View {
    @StateObject private var statusMonitor = StatusMonitor.shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                    .foregroundStyle(statusColor)
                Text("Geisterhand")
                    .font(.headline)
                Spacer()
                Text("v\(StatusRoute.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)

            Divider()

            // Server Status
            StatusRow(
                icon: "server.rack",
                title: "Server",
                status: statusMonitor.serverRunning ? "Running on :7676" : "Stopped",
                isOK: statusMonitor.serverRunning
            )

            // Permissions Status
            StatusRow(
                icon: "hand.tap",
                title: "Accessibility",
                status: statusMonitor.accessibilityGranted ? "Granted" : "Required",
                isOK: statusMonitor.accessibilityGranted
            )

            StatusRow(
                icon: "rectangle.dashed.badge.record",
                title: "Screen Recording",
                status: statusMonitor.screenRecordingGranted ? "Granted" : "Required",
                isOK: statusMonitor.screenRecordingGranted
            )

            Divider()

            // Actions
            if !statusMonitor.accessibilityGranted {
                Button {
                    PermissionManager.shared.openAccessibilitySettings()
                } label: {
                    Label("Grant Accessibility", systemImage: "gear")
                }
                .buttonStyle(.borderless)
            }

            if !statusMonitor.screenRecordingGranted {
                Button {
                    PermissionManager.shared.openScreenRecordingSettings()
                } label: {
                    Label("Grant Screen Recording", systemImage: "gear")
                }
                .buttonStyle(.borderless)
            }

            // Server Controls
            HStack(spacing: 8) {
                if statusMonitor.serverRunning {
                    Button("Stop Server") {
                        ServerManager.shared.stopServer()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            statusMonitor.updateStatus()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Restart") {
                        ServerManager.shared.restartServer()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            statusMonitor.updateStatus()
                        }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Start Server") {
                        ServerManager.shared.startServer()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            statusMonitor.updateStatus()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()

            // Footer actions
            HStack {
                Button {
                    openSettings()
                } label: {
                    Label("Settings...", systemImage: "gearshape")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 280)
    }

    private var statusColor: Color {
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

/// A row showing status information
struct StatusRow: View {
    let icon: String
    let title: String
    let status: String
    let isOK: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(isOK ? .green : .orange)

            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(status)
                .font(.caption)
                .foregroundColor(isOK ? .secondary : .orange)
        }
    }
}

#Preview {
    MenuBarView()
}
