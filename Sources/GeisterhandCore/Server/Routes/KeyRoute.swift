import Foundation
import Hummingbird

/// Handler for /key endpoint
public struct KeyRoute: Sendable {

    public init() {}

    /// Handles POST /key request
    /// Body: { "key": "s", "modifiers": ["cmd", "shift", ...] }
    /// PID-targeted: { "key": "return", "pid": 1234 }
    /// AX action: { "key": "return", "path": {"pid": 1234, "path": [0, 0, 1, 3]} }
    @MainActor
    public func handle(_ request: Request, context: some RequestContext) async throws -> Response {
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

        if let path = keyRequest.path {
            // AX action mode: map key to accessibility action
            return try handleAXAction(key: keyRequest.key, path: path, modifiers: modifiers)
        } else if let pid = keyRequest.pid {
            // PID-targeted CGEvent mode
            return try handlePIDTargeted(key: keyRequest.key, modifiers: modifiers, pid: pid)
        } else {
            // Standard global CGEvent mode (original behavior)
            return try handleGlobalCGEvent(key: keyRequest.key, modifiers: modifiers)
        }
    }

    /// Map key to accessibility action and perform it on the element
    @MainActor
    private func handleAXAction(key: String, path: ElementPath, modifiers: [KeyModifier]) throws -> Response {
        let service = AccessibilityService.shared
        let normalizedKey = key.lowercased()

        // Map keys to accessibility actions
        let action: AccessibilityAction
        switch normalizedKey {
        case "return", "enter":
            action = .confirm
        case "escape":
            action = .cancel
        case "space":
            action = .press
        default:
            let response = KeyResponse(
                success: false,
                key: key,
                modifiers: modifiers.map { $0.rawValue },
                error: "Key '\(key)' cannot be mapped to an accessibility action. Supported keys for path-based mode: return, enter, escape, space. For other keys, use 'pid' for PID-targeted CGEvent instead."
            )
            return try encodeJSON(response, status: .badRequest)
        }

        let result = service.performAction(path: path, action: action, value: nil)

        if result.success {
            let response = KeyResponse(
                success: true,
                key: key,
                modifiers: modifiers.map { $0.rawValue }
            )
            return try encodeJSON(response)
        } else {
            let response = KeyResponse(
                success: false,
                key: key,
                modifiers: modifiers.map { $0.rawValue },
                error: result.error ?? "Accessibility action failed"
            )
            return try encodeJSON(response, status: .internalServerError)
        }
    }

    /// PID-targeted CGEvent key press
    private func handlePIDTargeted(key: String, modifiers: [KeyModifier], pid: Int32) throws -> Response {
        let keyboardController = KeyboardController.shared

        do {
            try keyboardController.pressKey(key: key, modifiers: modifiers, targetPid: pid)

            let response = KeyResponse(
                success: true,
                key: key,
                modifiers: modifiers.map { $0.rawValue }
            )
            return try encodeJSON(response)

        } catch {
            let response = KeyResponse(
                success: false,
                key: key,
                modifiers: modifiers.map { $0.rawValue },
                error: error.localizedDescription
            )
            return try encodeJSON(response, status: .internalServerError)
        }
    }

    /// Standard global CGEvent key press (original behavior)
    private func handleGlobalCGEvent(key: String, modifiers: [KeyModifier]) throws -> Response {
        let keyboardController = KeyboardController.shared

        do {
            try keyboardController.pressKey(key: key, modifiers: modifiers)

            let response = KeyResponse(
                success: true,
                key: key,
                modifiers: modifiers.map { $0.rawValue }
            )
            return try encodeJSON(response)

        } catch {
            let response = KeyResponse(
                success: false,
                key: key,
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
