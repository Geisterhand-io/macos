import Foundation
import Hummingbird

/// Handler for /key endpoint
public struct KeyRoute: Sendable {

    public init() {}

    /// Handles POST /key request
    /// Body: { "key": "s", "modifiers": ["cmd", "shift", ...] }
    public func handle(_ request: Request, context: some RequestContext) async throws -> Response {
        let keyboardController = KeyboardController.shared

        // Decode request body
        let keyRequest: KeyRequest
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let body = try await request.body.collect(upTo: 1024 * 10) // 10KB limit
            keyRequest = try decoder.decode(KeyRequest.self, from: Data(buffer: body))
        } catch {
            return try errorResponse(message: "Invalid request body: \(error.localizedDescription)", code: 400)
        }

        // Validate key
        guard !keyRequest.key.isEmpty else {
            return try errorResponse(message: "Key cannot be empty", code: 400)
        }

        let modifiers = keyRequest.modifiers ?? []

        do {
            try keyboardController.pressKey(key: keyRequest.key, modifiers: modifiers)

            let response = KeyResponse(
                success: true,
                key: keyRequest.key,
                modifiers: modifiers.map { $0.rawValue }
            )
            return try encodeJSON(response)

        } catch {
            let response = KeyResponse(
                success: false,
                key: keyRequest.key,
                modifiers: modifiers.map { $0.rawValue },
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
