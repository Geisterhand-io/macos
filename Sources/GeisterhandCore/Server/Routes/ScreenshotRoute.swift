import Foundation
import Hummingbird

/// Handler for /screenshot endpoint
public struct ScreenshotRoute: Sendable {

    public init() {}

    /// Handles GET /screenshot request
    /// Query params:
    /// - format: "png" (default), "base64", or "jpeg"
    /// - display: display ID (optional)
    public func handle(_ request: Request, context: some RequestContext) async throws -> Response {
        let screenService = ScreenCaptureService.shared

        // Parse query parameters
        let format = request.uri.queryParameters.get("format") ?? "png"
        let displayIdString = request.uri.queryParameters.get("display")
        let displayId: UInt32? = displayIdString.flatMap { UInt32($0) }

        do {
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

            case "png":
                fallthrough
            default:
                let pngData = try await screenService.captureScreenAsPNG(displayId: displayId)

                return Response(
                    status: .ok,
                    headers: [.contentType: "image/png"],
                    body: .init(byteBuffer: ByteBuffer(data: pngData))
                )
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
