import SwiftUI
import GeisterhandCore

/// Settings window for the application
struct SettingsView: View {
    @AppStorage("serverHost") private var serverHost: String = "127.0.0.1"
    @AppStorage("serverPort") private var serverPort: Int = 7676
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    @StateObject private var statusMonitor = StatusMonitor.shared

    var body: some View {
        TabView {
            GeneralSettingsView(
                serverHost: $serverHost,
                serverPort: $serverPort,
                launchAtLogin: $launchAtLogin,
                statusMonitor: statusMonitor
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            PermissionsSettingsView(statusMonitor: statusMonitor)
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

/// General settings tab
struct GeneralSettingsView: View {
    @Binding var serverHost: String
    @Binding var serverPort: Int
    @Binding var launchAtLogin: Bool
    @ObservedObject var statusMonitor: StatusMonitor

    var body: some View {
        Form {
            Section {
                TextField("Host", text: $serverHost)
                    .textFieldStyle(.roundedBorder)

                TextField("Port", value: $serverPort, format: .number)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    if statusMonitor.serverRunning {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Server running on \(serverHost):\(serverPort)")
                            .foregroundStyle(.secondary)
                    } else {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("Server stopped")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Apply & Restart") {
                        ServerManager.shared.restartServer(host: serverHost, port: serverPort)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            statusMonitor.updateStatus()
                        }
                    }
                    .disabled(!statusMonitor.serverRunning)
                }
            } header: {
                Text("Server Configuration")
            }

            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .disabled(true) // TODO: Implement launch at login
                    .help("Coming soon")
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

/// Permissions settings tab
struct PermissionsSettingsView: View {
    @ObservedObject var statusMonitor: StatusMonitor

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: statusMonitor.accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(statusMonitor.accessibilityGranted ? .green : .red)

                    VStack(alignment: .leading) {
                        Text("Accessibility")
                            .font(.headline)
                        Text("Required for mouse and keyboard control")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !statusMonitor.accessibilityGranted {
                        Button("Open Settings") {
                            PermissionManager.shared.openAccessibilitySettings()
                        }
                    }
                }

                HStack {
                    Image(systemName: statusMonitor.screenRecordingGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(statusMonitor.screenRecordingGranted ? .green : .red)

                    VStack(alignment: .leading) {
                        Text("Screen Recording")
                            .font(.headline)
                        Text("Required for screenshots")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !statusMonitor.screenRecordingGranted {
                        Button("Open Settings") {
                            PermissionManager.shared.openScreenRecordingSettings()
                        }
                    }
                }
            } header: {
                Text("Required Permissions")
            }

            Section {
                Text("After granting permissions in System Settings, you may need to restart Geisterhand for changes to take effect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Refresh Status") {
                    statusMonitor.updateStatus()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

/// About tab
struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Geisterhand")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(StatusRoute.version)")
                .foregroundStyle(.secondary)

            Text("LLM-driven native app testing automation")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            VStack(spacing: 8) {
                Text("API Endpoints")
                    .font(.headline)

                Group {
                    Text("GET /status - Health check")
                    Text("GET /screenshot - Capture screen")
                    Text("POST /click - Click at coordinates")
                    Text("POST /type - Type text")
                    Text("POST /key - Press key with modifiers")
                    Text("POST /scroll - Scroll at position")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
}
