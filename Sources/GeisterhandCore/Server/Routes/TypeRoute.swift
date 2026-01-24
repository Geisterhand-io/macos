import Foundation
import Hummingbird

/// Handler for /type endpoint
public struct TypeRoute: Sendable {

    public init() {}

    /// Handles POST /type request
    /// Body: { "text": "string to type", "delay_ms": number }
    public func handle(_ request: Request, context: some RequestContext) async throws -> Response {
        let keyboardController = KeyboardController.shared

        // Decode request body
        let typeRequest: TypeRequest
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let body = try await request.body.collect(upTo: 1024 * 100) // 100KB limit for large text
            typeRequest = try decoder.decode(TypeRequest.self, from: Data(buffer: body))
        } catch {
            return try errorResponse(message: "Invalid request body: \(error.localizedDescription)", code: 400)
        }

        // Validate text
        guard !typeRequest.text.isEmpty else {
            return try errorResponse(message: "Text cannot be empty", code: 400)
        }

        let delayMs = typeRequest.delayMs ?? 0

        do {
            let typedCount = try keyboardController.type(text: typeRequest.text, delayMs: delayMs)

            let response = TypeResponse(
                success: true,
                charactersTyped: typedCount
            )
            return try encodeJSON(response)

        } catch {
            let response = TypeResponse(
                success: false,
                charactersTyped: 0,
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
