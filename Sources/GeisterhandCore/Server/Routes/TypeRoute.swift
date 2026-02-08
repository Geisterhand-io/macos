import Foundation
import Hummingbird

/// Handler for /type endpoint
public struct TypeRoute: Sendable {

    public init() {}

    /// Handles POST /type request
    /// Body: { "text": "string to type", "delay_ms": number }
    /// Background mode: { "text": "value", "pid": 1234, "role": "AXTextField", "title_contains": "Email" }
    /// Direct path mode: { "text": "value", "path": {"pid": 1234, "path": [0, 0, 1, 2]} }
    @MainActor
    public func handle(_ request: Request, context: some RequestContext) async throws -> Response {
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

        // Check if this is an element-targeted (background mode) request
        let hasElementTarget = typeRequest.path != nil || typeRequest.role != nil || typeRequest.title != nil || typeRequest.titleContains != nil

        if let path = typeRequest.path {
            // Direct path mode: use AX setValue
            return try handleSetValue(text: typeRequest.text, path: path)
        } else if hasElementTarget {
            // Query-based element targeting: find element then setValue
            return try handleElementQuery(typeRequest: typeRequest)
        } else {
            // Standard CGEvent keyboard typing
            return try handleCGEventType(typeRequest: typeRequest)
        }
    }

    /// Set value via direct element path (accessibility)
    @MainActor
    private func handleSetValue(text: String, path: ElementPath) throws -> Response {
        let service = AccessibilityService.shared
        let result = service.performAction(path: path, action: .setValue, value: text)

        if result.success {
            let response = TypeResponse(
                success: true,
                charactersTyped: text.count
            )
            return try encodeJSON(response)
        } else {
            let response = TypeResponse(
                success: false,
                charactersTyped: 0,
                error: result.error ?? "Failed to set value on element"
            )
            return try encodeJSON(response, status: .internalServerError)
        }
    }

    /// Find element by query criteria, then set its value
    @MainActor
    private func handleElementQuery(typeRequest: TypeRequest) throws -> Response {
        let service = AccessibilityService.shared

        let query = ElementQuery(
            role: typeRequest.role,
            titleContains: typeRequest.titleContains,
            title: typeRequest.title,
            maxResults: 1
        )

        let findResult = service.findElements(pid: typeRequest.pid, query: query)

        guard findResult.success, let elements = findResult.elements, let element = elements.first else {
            let error = findResult.error ?? "No matching element found"
            let response = TypeResponse(success: false, charactersTyped: 0, error: error)
            return try encodeJSON(response, status: .badRequest)
        }

        // Set value on the found element
        let actionResult = service.performAction(path: element.path, action: .setValue, value: typeRequest.text)

        if actionResult.success {
            let response = TypeResponse(
                success: true,
                charactersTyped: typeRequest.text.count
            )
            return try encodeJSON(response)
        } else {
            let response = TypeResponse(
                success: false,
                charactersTyped: 0,
                error: actionResult.error ?? "Failed to set value on element"
            )
            return try encodeJSON(response, status: .internalServerError)
        }
    }

    /// Standard CGEvent-based keyboard typing (original behavior)
    private func handleCGEventType(typeRequest: TypeRequest) throws -> Response {
        let keyboardController = KeyboardController.shared
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
