import Foundation
import Hummingbird

/// Handler for /type endpoint
public struct TypeRoute: Sendable {
    let targetApp: TargetApp?

    public init(targetApp: TargetApp? = nil) {
        self.targetApp = targetApp
    }

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

        // Validate mode
        let mode = typeRequest.mode ?? "replace"
        guard mode == "replace" || mode == "keys" else {
            return try errorResponse(message: "Invalid mode '\(mode)'. Must be 'replace' or 'keys'", code: 400)
        }

        // Check if this is an element-targeted (background mode) request
        let hasElementTarget = typeRequest.path != nil || typeRequest.role != nil || typeRequest.title != nil || typeRequest.titleContains != nil

        if mode == "keys" {
            // Character-by-character CGEvent key presses
            let effectivePid: Int32?
            if let pid = typeRequest.pid {
                effectivePid = pid
            } else if let path = typeRequest.path {
                effectivePid = path.pid
            } else {
                effectivePid = targetApp?.pid
            }

            // If element targeting params are present, focus the element first
            if hasElementTarget {
                try focusTargetElement(typeRequest: typeRequest, effectivePid: effectivePid)
            }

            return try handleCGEventType(typeRequest: typeRequest, targetPid: effectivePid)
        } else if let path = typeRequest.path {
            // Direct path mode: use AX setValue
            return try handleSetValue(text: typeRequest.text, path: path)
        } else if hasElementTarget {
            // Query-based element targeting: find element then setValue
            return try handleElementQuery(typeRequest: typeRequest, effectivePid: typeRequest.pid ?? targetApp?.pid)
        } else {
            // Standard CGEvent keyboard typing
            return try handleCGEventType(typeRequest: typeRequest, targetPid: targetApp?.pid)
        }
    }

    /// Focus an element before typing via CGEvents (for "keys" mode with element targeting)
    @MainActor
    private func focusTargetElement(typeRequest: TypeRequest, effectivePid: Int32?) throws {
        let service = AccessibilityService.shared

        if let path = typeRequest.path {
            _ = service.performAction(path: path, action: .focus, value: nil)
        } else {
            let query = ElementQuery(
                role: typeRequest.role,
                titleContains: typeRequest.titleContains,
                title: typeRequest.title,
                maxResults: 1
            )
            let findResult = service.findElements(pid: effectivePid, query: query)
            if let elements = findResult.elements, let element = elements.first {
                _ = service.performAction(path: element.path, action: .focus, value: nil)
            }
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
    private func handleElementQuery(typeRequest: TypeRequest, effectivePid: Int32?) throws -> Response {
        let service = AccessibilityService.shared

        let query = ElementQuery(
            role: typeRequest.role,
            titleContains: typeRequest.titleContains,
            title: typeRequest.title,
            maxResults: 1
        )

        let findResult = service.findElements(pid: effectivePid, query: query)

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
    private func handleCGEventType(typeRequest: TypeRequest, targetPid: Int32? = nil) throws -> Response {
        let keyboardController = KeyboardController.shared
        let delayMs = typeRequest.delayMs ?? 0

        do {
            let typedCount = try keyboardController.type(text: typeRequest.text, delayMs: delayMs, targetPid: targetPid)

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
