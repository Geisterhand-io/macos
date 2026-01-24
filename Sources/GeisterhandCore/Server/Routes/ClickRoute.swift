import Foundation
import Hummingbird

/// Handler for /click endpoint
public struct ClickRoute: Sendable {

    public init() {}

    /// Handles POST /click request
    /// Body: { "x": number, "y": number, "button": "left"|"right"|"center", "click_count": number, "modifiers": ["cmd", "shift", ...] }
    public func handle(_ request: Request, context: some RequestContext) async throws -> Response {
        let mouseController = MouseController.shared

        // Decode request body
        let clickRequest: ClickRequest
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let body = try await request.body.collect(upTo: 1024 * 10) // 10KB limit
            clickRequest = try decoder.decode(ClickRequest.self, from: Data(buffer: body))
        } catch {
            return try errorResponse(message: "Invalid request body: \(error.localizedDescription)", code: 400)
        }

        // Validate coordinates
        guard clickRequest.x >= 0 && clickRequest.y >= 0 else {
            return try errorResponse(message: "Invalid coordinates: x and y must be non-negative", code: 400)
        }

        let button = clickRequest.button ?? .left
        let clickCount = clickRequest.clickCount ?? 1
        let modifiers = clickRequest.modifiers ?? []

        do {
            try mouseController.click(
                x: clickRequest.x,
                y: clickRequest.y,
                button: button,
                clickCount: clickCount,
                modifiers: modifiers
            )

            let response = ClickResponse(
                success: true,
                x: clickRequest.x,
                y: clickRequest.y,
                button: button.rawValue
            )
            return try encodeJSON(response)

        } catch {
            let response = ClickResponse(
                success: false,
                x: clickRequest.x,
                y: clickRequest.y,
                button: button.rawValue,
                error: error.localizedDescription
            )
            return try encodeJSON(response, status: .internalServerError)
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

    private func errorResponse(message: String, code: Int) throws -> Response {
        let error = ErrorResponse(error: message, code: code)
        return try encodeJSON(error, status: .badRequest)
    }
}
