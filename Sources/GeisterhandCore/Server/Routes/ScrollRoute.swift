import Foundation
import Hummingbird

/// Handler for /scroll endpoint
public struct ScrollRoute: Sendable {

    public init() {}

    /// Handles POST /scroll request
    /// Body: { "x": number, "y": number, "delta_x": number, "delta_y": number }
    public func handle(_ request: Request, context: some RequestContext) async throws -> Response {
        let mouseController = MouseController.shared

        // Decode request body
        let scrollRequest: ScrollRequest
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let body = try await request.body.collect(upTo: 1024 * 10) // 10KB limit
            scrollRequest = try decoder.decode(ScrollRequest.self, from: Data(buffer: body))
        } catch {
            return try errorResponse(message: "Invalid request body: \(error.localizedDescription)", code: 400)
        }

        // Validate coordinates
        guard scrollRequest.x >= 0 && scrollRequest.y >= 0 else {
            return try errorResponse(message: "Invalid coordinates: x and y must be non-negative", code: 400)
        }

        let deltaX = scrollRequest.deltaX ?? 0
        let deltaY = scrollRequest.deltaY ?? 0

        // Validate that at least one delta is provided
        guard deltaX != 0 || deltaY != 0 else {
            return try errorResponse(message: "At least one of delta_x or delta_y must be non-zero", code: 400)
        }

        do {
            try mouseController.scroll(
                x: scrollRequest.x,
                y: scrollRequest.y,
                deltaX: deltaX,
                deltaY: deltaY
            )

            let response = ScrollResponse(
                success: true,
                x: scrollRequest.x,
                y: scrollRequest.y,
                deltaX: deltaX,
                deltaY: deltaY
            )
            return try encodeJSON(response)

        } catch {
            let response = ScrollResponse(
                success: false,
                x: scrollRequest.x,
                y: scrollRequest.y,
                deltaX: deltaX,
                deltaY: deltaY,
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
