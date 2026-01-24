import Foundation
import Hummingbird
import AppKit

/// Handler for /status endpoint
public struct StatusRoute: Sendable {
    public static let version = "1.0.0"

    public init() {}

    /// Handles GET /status request
    public func handle(_ request: Request, context: some RequestContext) async throws -> Response {
        let permissionManager = PermissionManager.shared
        let screenService = ScreenCaptureService.shared

        // Get frontmost app info
        let frontmostApp = getFrontmostAppInfo()

        // Get screen size
        let screenSize = await screenService.getMainDisplaySize()

        let response = StatusResponse(
            status: "ok",
            version: Self.version,
            serverRunning: true,
            permissions: permissionManager.permissionStatus,
            frontmostApp: frontmostApp,
            screenSize: screenSize
        )

        return try encodeJSON(response)
    }

    private func getFrontmostAppInfo() -> AppInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return AppInfo(
            name: app.localizedName ?? "Unknown",
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier
        )
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> Response {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(value)

        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(data: data))
        )
    }
}
