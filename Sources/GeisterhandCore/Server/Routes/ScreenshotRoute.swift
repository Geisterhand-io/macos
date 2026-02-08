import Foundation
import Hummingbird

/// Handler for /screenshot endpoint
public struct ScreenshotRoute: Sendable {
    let targetApp: TargetApp?

    public init(targetApp: TargetApp? = nil) {
        self.targetApp = targetApp
    }

    /// Handles GET /screenshot request
    /// Query params:
    /// - format: "png" (default), "base64", or "jpeg"
    /// - display: display ID (optional)
    /// - app: application name for app-specific screenshot (optional)
    /// - windowId: specific window ID to capture (optional)
    public func handle(_ request: Request, context: some RequestContext) async throws -> Response {
        let screenService = ScreenCaptureService.shared

        // Parse query parameters
        let format = request.uri.queryParameters.get("format") ?? "png"
        let displayIdString = request.uri.queryParameters.get("display")
        let displayId: UInt32? = displayIdString.flatMap { UInt32($0) }
        let appName = request.uri.queryParameters.get("app")
        let windowIdString = request.uri.queryParameters.get("windowId")
        let windowId: UInt32? = windowIdString.flatMap { UInt32($0) }

        // Use targetApp as fallback for app name
        let effectiveAppName = appName ?? targetApp?.appName

        do {
            // Determine capture mode: window (by app or ID) vs screen
            if let effectiveAppName = effectiveAppName {
                // Capture by app name
                return try await captureByApp(appName: effectiveAppName, format: format, screenService: screenService)
            } else if let windowId = windowId {
                // Capture by window ID
                return try await captureByWindowId(windowId: windowId, format: format, screenService: screenService)
            } else {
                // Default: capture screen
                return try await captureScreen(displayId: displayId, format: format, screenService: screenService)
            }
        } catch {
            let errorResponse = ScreenshotResponse(
                success: false,
                format: format,
                width: 0,
                height: 0,
                error: error.localizedDescription
            )
            return try encodeJSON(errorResponse, status: .internalServerError)
        }
    }

    // MARK: - Capture Methods

    private func captureByApp(appName: String, format: String, screenService: ScreenCaptureService) async throws -> Response {
        switch format.lowercased() {
        case "base64":
            let (base64, windowInfo) = try await screenService.captureWindowByAppAsBase64(appName: appName)
            let response = ScreenshotResponse(
                success: true,
                format: "base64",
                width: Int(windowInfo.frame.width),
                height: Int(windowInfo.frame.height),
                data: base64,
                window: windowInfo
            )
            return try encodeJSON(response)

        case "jpeg", "jpg":
            let (image, _) = try await screenService.captureWindowByApp(appName: appName)
            let encoder = ImageEncoder()
            let jpegData = try encoder.encodeJPEG(image, quality: 0.85)
            return Response(
                status: .ok,
                headers: [.contentType: "image/jpeg"],
                body: .init(byteBuffer: ByteBuffer(data: jpegData))
            )

        default: // png
            let (pngData, _) = try await screenService.captureWindowByAppAsPNG(appName: appName)
            return Response(
                status: .ok,
                headers: [.contentType: "image/png"],
                body: .init(byteBuffer: ByteBuffer(data: pngData))
            )
        }
    }

    private func captureByWindowId(windowId: UInt32, format: String, screenService: ScreenCaptureService) async throws -> Response {
        switch format.lowercased() {
        case "base64":
            let (base64, width, height) = try await screenService.captureWindowAsBase64(windowId: windowId)
            let response = ScreenshotResponse(
                success: true,
                format: "base64",
                width: width,
                height: height,
                data: base64
            )
            return try encodeJSON(response)

        case "jpeg", "jpg":
            let image = try await screenService.captureWindow(windowId: windowId)
            let encoder = ImageEncoder()
            let jpegData = try encoder.encodeJPEG(image, quality: 0.85)
            return Response(
                status: .ok,
                headers: [.contentType: "image/jpeg"],
                body: .init(byteBuffer: ByteBuffer(data: jpegData))
            )

        default: // png
            let (pngData, _, _) = try await screenService.captureWindowAsPNG(windowId: windowId)
            return Response(
                status: .ok,
                headers: [.contentType: "image/png"],
                body: .init(byteBuffer: ByteBuffer(data: pngData))
            )
        }
    }

    private func captureScreen(displayId: UInt32?, format: String, screenService: ScreenCaptureService) async throws -> Response {
        switch format.lowercased() {
        case "base64":
            let base64 = try await screenService.captureScreenAsBase64(displayId: displayId)
            let image = try await screenService.captureScreen(displayId: displayId)
            let response = ScreenshotResponse(
                success: true,
                format: "base64",
                width: image.width,
                height: image.height,
                data: base64
            )
            return try encodeJSON(response)

        case "jpeg", "jpg":
            let image = try await screenService.captureScreen(displayId: displayId)
            let encoder = ImageEncoder()
            let jpegData = try encoder.encodeJPEG(image, quality: 0.85)
            return Response(
                status: .ok,
                headers: [.contentType: "image/jpeg"],
                body: .init(byteBuffer: ByteBuffer(data: jpegData))
            )

        default: // png
            let pngData = try await screenService.captureScreenAsPNG(displayId: displayId)
            return Response(
                status: .ok,
                headers: [.contentType: "image/png"],
                body: .init(byteBuffer: ByteBuffer(data: pngData))
            )
        }
    }

    private func encodeJSON<T: Encodable>(_ value: T, status: HTTPResponse.Status = .ok) throws -> Response {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(value)

        return Response(
            status: status,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(data: data))
        )
    }
}
