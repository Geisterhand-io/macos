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

            // Claude Code Integration
            ClaudeCodeSection()

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

/// Claude Code integration section
struct ClaudeCodeSection: View {
    @State private var isConfigured: Bool = false
    @State private var isChecking: Bool = true
    @State private var isInstalling: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccess: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "terminal")
                    .frame(width: 20)
                    .foregroundStyle(isConfigured ? .green : .secondary)
                Text("Claude Code")
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isChecking {
                    ProgressView()
                        .scaleEffect(0.6)
                } else if isConfigured {
                    Text("Configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not configured")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if showSuccess {
                Text("Restart Claude Code to use Geisterhand!")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !isChecking && !isConfigured {
                Button {
                    installClaudeCodeIntegration()
                } label: {
                    if isInstalling {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Installing...")
                    } else {
                        Label("Enable Claude Code Integration", systemImage: "plus.circle")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isInstalling)
            }
        }
        .onAppear {
            checkClaudeCodeConfiguration()
        }
    }

    private func checkClaudeCodeConfiguration() {
        isChecking = true
        DispatchQueue.global(qos: .userInitiated).async {
            let configured = ClaudeCodeHelper.isConfigured()
            DispatchQueue.main.async {
                isConfigured = configured
                isChecking = false
            }
        }
    }

    private func installClaudeCodeIntegration() {
        isInstalling = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let result = ClaudeCodeHelper.install()
            DispatchQueue.main.async {
                isInstalling = false
                switch result {
                case .success:
                    isConfigured = true
                    showSuccess = true
                case .notInstalled:
                    errorMessage = "Claude Code CLI not found. Install it first."
                case .failed(let message):
                    errorMessage = message
                }
            }
        }
    }
}

/// Helper for Claude Code integration
enum ClaudeCodeHelper {
    enum InstallResult {
        case success
        case notInstalled
        case failed(String)
    }

    /// Common installation paths for Claude Code CLI
    private static var claudePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(home)/.npm-global/bin/claude",
            "/usr/bin/claude"
        ]
    }

    /// Find the claude CLI executable
    static func findClaudePath() -> String? {
        // Check known paths first (GUI apps don't inherit shell PATH)
        for path in claudePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallback: try which (works if PATH is set)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let path = path, !path.isEmpty {
                    return path
                }
            }
        } catch {}

        return nil
    }

    /// Check if geisterhand is configured in Claude Code
    static func isConfigured() -> Bool {
        guard let claudePath = findClaudePath() else {
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["mcp", "list"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains("geisterhand")
        } catch {
            return false
        }
    }

    /// Install geisterhand MCP server to Claude Code
    static func install() -> InstallResult {
        // Find claude CLI
        guard let claudePath = findClaudePath() else {
            return .notInstalled
        }

        // Run claude mcp add-json
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = [
            "mcp", "add-json", "geisterhand",
            #"{"type":"stdio","command":"npx","args":["geisterhand-mcp"]}"#,
            "--scope", "user"
        ]

        let errorPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return .success
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return .failed(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

#Preview {
    MenuBarView()
}
