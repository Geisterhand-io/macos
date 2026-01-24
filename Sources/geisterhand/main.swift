import Foundation
import ArgumentParser
import GeisterhandCore

@main
struct Geisterhand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "geisterhand",
        abstract: "Command-line interface for Geisterhand automation",
        version: StatusRoute.version,
        subcommands: [
            Screenshot.self,
            Click.self,
            TypeText.self,
            Key.self,
            Scroll.self,
            Status.self,
            Server.self
        ],
        defaultSubcommand: Status.self
    )
}

// MARK: - Screenshot Command

struct Screenshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Capture a screenshot"
    )

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String?

    @Option(name: .shortAndLong, help: "Display ID to capture")
    var display: UInt32?

    @Flag(name: .long, help: "Output as base64 to stdout")
    var base64: Bool = false

    func run() async throws {
        let screenService = ScreenCaptureService.shared

        if base64 {
            let base64String = try await screenService.captureScreenAsBase64(displayId: display)
            print(base64String)
        } else if let outputPath = output {
            try await screenService.captureScreenToFile(path: outputPath, displayId: display)
            print("Screenshot saved to: \(outputPath)")
        } else {
            // Default to /tmp/screenshot.png
            let defaultPath = "/tmp/geisterhand-screenshot.png"
            try await screenService.captureScreenToFile(path: defaultPath, displayId: display)
            print("Screenshot saved to: \(defaultPath)")
        }
    }
}

// MARK: - Click Command

struct Click: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Click at screen coordinates"
    )

    @Argument(help: "X coordinate")
    var x: Double

    @Argument(help: "Y coordinate")
    var y: Double

    @Option(name: .shortAndLong, help: "Mouse button (left, right, center)")
    var button: String = "left"

    @Option(name: .shortAndLong, help: "Number of clicks")
    var count: Int = 1

    @Flag(name: .long, help: "Hold Command key")
    var cmd: Bool = false

    @Flag(name: .long, help: "Hold Shift key")
    var shift: Bool = false

    @Flag(name: .long, help: "Hold Option/Alt key")
    var alt: Bool = false

    @Flag(name: .long, help: "Hold Control key")
    var ctrl: Bool = false

    func run() throws {
        let mouseController = MouseController.shared

        let mouseButton: MouseButton
        switch button.lowercased() {
        case "right":
            mouseButton = .right
        case "center", "middle":
            mouseButton = .center
        default:
            mouseButton = .left
        }

        var modifiers: [KeyModifier] = []
        if cmd { modifiers.append(.cmd) }
        if shift { modifiers.append(.shift) }
        if alt { modifiers.append(.alt) }
        if ctrl { modifiers.append(.ctrl) }

        try mouseController.click(
            x: x,
            y: y,
            button: mouseButton,
            clickCount: count,
            modifiers: modifiers
        )

        print("Clicked at (\(x), \(y)) with \(button) button")
    }
}

// MARK: - Type Command

struct TypeText: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text"
    )

    @Argument(help: "Text to type")
    var text: String

    @Option(name: .shortAndLong, help: "Delay between keystrokes in milliseconds")
    var delay: Int = 0

    func run() throws {
        let keyboardController = KeyboardController.shared

        let count = try keyboardController.type(text: text, delayMs: delay)
        print("Typed \(count) characters")
    }
}

// MARK: - Key Command

struct Key: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Press a key with optional modifiers"
    )

    @Argument(help: "Key to press (e.g., 'a', 'return', 'f1')")
    var key: String

    @Flag(name: .long, help: "Hold Command key")
    var cmd: Bool = false

    @Flag(name: .long, help: "Hold Shift key")
    var shift: Bool = false

    @Flag(name: .long, help: "Hold Option/Alt key")
    var alt: Bool = false

    @Flag(name: .long, help: "Hold Control key")
    var ctrl: Bool = false

    @Flag(name: .long, help: "Hold Function key")
    var fn: Bool = false

    func run() throws {
        let keyboardController = KeyboardController.shared

        var modifiers: [KeyModifier] = []
        if cmd { modifiers.append(.cmd) }
        if shift { modifiers.append(.shift) }
        if alt { modifiers.append(.alt) }
        if ctrl { modifiers.append(.ctrl) }
        if fn { modifiers.append(.fn) }

        try keyboardController.pressKey(key: key, modifiers: modifiers)

        let modifierStr = modifiers.isEmpty ? "" : " with \(modifiers.map { $0.rawValue }.joined(separator: "+"))"
        print("Pressed '\(key)'\(modifierStr)")
    }
}

// MARK: - Scroll Command

struct Scroll: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Scroll at screen coordinates"
    )

    @Argument(help: "X coordinate")
    var x: Double

    @Argument(help: "Y coordinate")
    var y: Double

    @Option(name: .long, help: "Vertical scroll delta (negative = up, positive = down)")
    var delta: Double = 0

    @Option(name: .long, help: "Horizontal scroll delta (negative = left, positive = right)")
    var deltaX: Double = 0

    func run() throws {
        let mouseController = MouseController.shared

        guard delta != 0 || deltaX != 0 else {
            print("Error: At least one of --delta or --delta-x must be specified")
            throw ExitCode.failure
        }

        try mouseController.scroll(x: x, y: y, deltaX: deltaX, deltaY: delta)

        print("Scrolled at (\(x), \(y)) with delta (\(deltaX), \(delta))")
    }
}

// MARK: - Status Command

struct Status: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show current status"
    )

    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    func run() async throws {
        let permissionManager = PermissionManager.shared
        let screenService = ScreenCaptureService.shared

        let accessibilityGranted = permissionManager.isAccessibilityGranted
        let screenRecordingGranted = permissionManager.isScreenRecordingGranted
        let screenSize = await screenService.getMainDisplaySize()

        if json {
            let status: [String: Any] = [
                "accessibility": accessibilityGranted,
                "screen_recording": screenRecordingGranted,
                "screen_width": screenSize.width,
                "screen_height": screenSize.height
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: status, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            print("Geisterhand Status")
            print("==================")
            print("Accessibility: \(accessibilityGranted ? "Granted" : "Not Granted")")
            print("Screen Recording: \(screenRecordingGranted ? "Granted" : "Not Granted")")
            print("Screen Size: \(Int(screenSize.width))x\(Int(screenSize.height))")

            if !accessibilityGranted {
                print("\nTo grant accessibility permission:")
                print("  System Settings > Privacy & Security > Accessibility")
            }

            if !screenRecordingGranted {
                print("\nTo grant screen recording permission:")
                print("  System Settings > Privacy & Security > Screen Recording")
            }
        }
    }
}

// MARK: - Server Command

struct Server: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Run the HTTP server (standalone mode)"
    )

    @Option(name: .shortAndLong, help: "Host to bind to")
    var host: String = "127.0.0.1"

    @Option(name: .shortAndLong, help: "Port to listen on")
    var port: Int = 7676

    func run() async throws {
        print("Starting Geisterhand server on \(host):\(port)...")

        let server = GeisterhandServer(host: host, port: port)
        try await server.start()
    }
}
