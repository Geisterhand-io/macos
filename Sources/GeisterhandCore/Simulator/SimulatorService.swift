import Foundation
import AppKit
import ImageIO

/// Service for interacting with iOS Simulator via xcrun simctl
public actor SimulatorService {
    public static let shared = SimulatorService()

    /// macOS title bar height in points
    private static let titleBarHeight: Double = 28.0

    /// Device info returned by simctl
    public struct DeviceInfo: Sendable {
        public let udid: String
        public let name: String
        public let state: String
        public let runtime: String
    }

    /// Simulator coordinate mapping info
    public struct CoordinateMapping: Sendable {
        /// The simulator window frame in screen coordinates
        public let windowFrame: WindowFrame
        /// Scale factor: how many screen points per iOS logical point
        public let scale: Double
        /// Offset from window origin to iOS content origin
        public let contentOffsetX: Double
        public let contentOffsetY: Double
        /// iOS logical screen size
        public let iosWidth: Double
        public let iosHeight: Double
    }

    // MARK: - simctl operations

    /// Get the booted device UDID, or nil if none booted
    public func bootedDeviceUDID() throws -> String? {
        let result = try runSimctl(["list", "devices", "booted", "-j"])
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: Any] else {
            return nil
        }
        for (_, runtimeDevices) in devices {
            guard let deviceList = runtimeDevices as? [[String: Any]] else { continue }
            for device in deviceList {
                if let state = device["state"] as? String, state == "Booted",
                   let udid = device["udid"] as? String {
                    return udid
                }
            }
        }
        return nil
    }

    /// Get device info for the booted simulator
    public func bootedDeviceInfo() throws -> DeviceInfo? {
        let result = try runSimctl(["list", "devices", "booted", "-j"])
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [String: Any] else {
            return nil
        }
        for (runtime, runtimeDevices) in devices {
            guard let deviceList = runtimeDevices as? [[String: Any]] else { continue }
            for device in deviceList {
                if let state = device["state"] as? String, state == "Booted",
                   let udid = device["udid"] as? String,
                   let name = device["name"] as? String {
                    return DeviceInfo(udid: udid, name: name, state: state, runtime: runtime)
                }
            }
        }
        return nil
    }

    /// Take a screenshot via simctl (clean iOS content, no simulator chrome)
    /// Returns PNG data
    public func screenshot() throws -> Data {
        let tmpPath = NSTemporaryDirectory() + "geisterhand-sim-\(ProcessInfo.processInfo.processIdentifier).png"
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }
        _ = try runSimctl(["io", "booted", "screenshot", "--type=png", tmpPath])
        return try Data(contentsOf: URL(fileURLWithPath: tmpPath))
    }

    /// Get the iOS logical screen size from the simctl screenshot dimensions
    /// and the device's scale factor
    public func iOSScreenSize() throws -> (width: Double, height: Double) {
        let pngData = try screenshot()
        guard let imageSource = CGImageSourceCreateWithData(pngData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw SimulatorError.screenshotFailed("Could not decode screenshot")
        }
        // simctl screenshots are at device pixel resolution
        // We need to figure out the logical size
        // Common scale factors: 2x (iPad, iPhone SE), 3x (iPhone Pro)
        let pixelWidth = Double(image.width)
        let pixelHeight = Double(image.height)

        // Detect scale factor from common device resolutions
        let scaleFactor = detectScaleFactor(pixelWidth: pixelWidth, pixelHeight: pixelHeight)
        return (width: pixelWidth / scaleFactor, height: pixelHeight / scaleFactor)
    }

    /// Compute coordinate mapping between iOS logical points and screen coordinates
    public func computeCoordinateMapping() async throws -> CoordinateMapping {
        // Get simulator window frame
        let simPid = try getSimulatorPid()
        guard let windowFrame = try await ScreenCaptureService.shared.getMainWindowFrame(pid: simPid) else {
            throw SimulatorError.noSimulatorWindow
        }

        // Get iOS screen size from simctl screenshot
        let pngData = try screenshot()
        guard let imageSource = CGImageSourceCreateWithData(pngData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw SimulatorError.screenshotFailed("Could not decode screenshot")
        }
        let pixelWidth = Double(image.width)
        let pixelHeight = Double(image.height)
        let deviceScale = detectScaleFactor(pixelWidth: pixelWidth, pixelHeight: pixelHeight)
        let iosWidth = pixelWidth / deviceScale
        let iosHeight = pixelHeight / deviceScale

        // The simulator window content area (below title bar) contains the iOS screen
        let contentWidth = windowFrame.width
        let contentHeight = windowFrame.height - Self.titleBarHeight

        // Scale: how many macOS screen points per iOS logical point
        let scale = min(contentWidth / iosWidth, contentHeight / iosHeight)

        // Content is centered if aspect ratios differ
        let renderedWidth = iosWidth * scale
        let renderedHeight = iosHeight * scale
        let contentOffsetX = (contentWidth - renderedWidth) / 2.0
        let contentOffsetY = Self.titleBarHeight + (contentHeight - renderedHeight) / 2.0

        return CoordinateMapping(
            windowFrame: windowFrame,
            scale: scale,
            contentOffsetX: contentOffsetX,
            contentOffsetY: contentOffsetY,
            iosWidth: iosWidth,
            iosHeight: iosHeight
        )
    }

    /// Convert iOS logical coordinates to screen-absolute coordinates
    public func iosToScreen(x: Double, y: Double, mapping: CoordinateMapping) -> (screenX: Double, screenY: Double) {
        let screenX = mapping.windowFrame.x + mapping.contentOffsetX + (x * mapping.scale)
        let screenY = mapping.windowFrame.y + mapping.contentOffsetY + (y * mapping.scale)
        return (screenX, screenY)
    }

    /// Get the PID of the Simulator.app process
    public func getSimulatorPid() throws -> Int32 {
        let workspace = NSWorkspace.shared
        if let simApp = workspace.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.iphonesimulator"
        }) {
            return simApp.processIdentifier
        }
        throw SimulatorError.simulatorNotRunning
    }

    // MARK: - Private helpers

    private func runSimctl(_ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw SimulatorError.simctlFailed("xcrun simctl \(args.joined(separator: " ")) failed with status \(process.terminationStatus)")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Detect device scale factor from pixel dimensions
    private func detectScaleFactor(pixelWidth: Double, pixelHeight: Double) -> Double {
        // Common iOS device resolutions (portrait, width x height)
        // 3x devices: iPhone Pro/Max (1179x2556, 1290x2796, 1320x2868)
        // 2x devices: iPad (2048x2732, 2360x1640, 2388x1668, 2732x2048, 2160x1620)
        //             iPhone SE (750x1334)
        let maxDim = max(pixelWidth, pixelHeight)
        let minDim = min(pixelWidth, pixelHeight)

        // If width/3 and height/3 give clean numbers typical of iOS logical sizes, it's 3x
        if minDim.truncatingRemainder(dividingBy: 3) == 0 &&
           maxDim.truncatingRemainder(dividingBy: 3) == 0 {
            let logicalMin = minDim / 3.0
            let logicalMax = maxDim / 3.0
            // iPhone logical widths: 393, 402, 430, 440
            if logicalMin >= 350 && logicalMin <= 500 && logicalMax >= 700 {
                return 3.0
            }
        }

        // Default: 2x (iPad and most non-Pro devices)
        return 2.0
    }

    // MARK: - Errors

    public enum SimulatorError: Error, LocalizedError {
        case simulatorNotRunning
        case noSimulatorWindow
        case noBootedDevice
        case simctlFailed(String)
        case screenshotFailed(String)

        public var errorDescription: String? {
            switch self {
            case .simulatorNotRunning: return "Simulator.app is not running"
            case .noSimulatorWindow: return "Could not find Simulator window"
            case .noBootedDevice: return "No booted simulator device found"
            case .simctlFailed(let msg): return "simctl failed: \(msg)"
            case .screenshotFailed(let msg): return "Screenshot failed: \(msg)"
            }
        }
    }
}
