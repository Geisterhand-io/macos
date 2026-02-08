import Foundation
import Hummingbird

/// Handler for /menu endpoints
public struct MenuRoute: Sendable {
    let targetApp: TargetApp?

    public init(targetApp: TargetApp? = nil) {
        self.targetApp = targetApp
    }

    // MARK: - GET /menu

    /// Handles GET /menu request
    /// Query params: app (required) - application name
    @MainActor
    public func handleGet(_ request: Request, context: some RequestContext) async throws -> Response {
        let service = MenuService.shared

        // Parse query parameters
        let appName = request.uri.queryParameters.get("app") ?? targetApp?.appName
        guard let appName = appName, !appName.isEmpty else {
            return try errorResponse(message: "Missing required query parameter: app", code: 400)
        }

        // Get menus
        let response = service.getMenus(appName: appName)

        if response.success {
            return try encodeJSON(response)
        } else {
            return try encodeJSON(response, status: .badRequest)
        }
    }

    // MARK: - POST /menu

    /// Handles POST /menu request
    /// Body: { "app": string, "path": [string] }
    @MainActor
    public func handleTrigger(_ request: Request, context: some RequestContext) async throws -> Response {
        let service = MenuService.shared

        // Decode request body
        let triggerRequest: MenuTriggerRequest
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let body = try await request.body.collect(upTo: 1024 * 10)
            triggerRequest = try decoder.decode(MenuTriggerRequest.self, from: Data(buffer: body))
        } catch {
            return try errorResponse(message: "Invalid request body: \(error.localizedDescription)", code: 400)
        }

        // Use targetApp as fallback for app name
        let effectiveApp = triggerRequest.app.isEmpty ? (targetApp?.appName ?? "") : triggerRequest.app

        // Validate
        guard !effectiveApp.isEmpty else {
            return try errorResponse(message: "App name cannot be empty", code: 400)
        }
        guard !triggerRequest.path.isEmpty else {
            return try errorResponse(message: "Menu path cannot be empty", code: 400)
        }

        // Trigger menu
        let response = service.triggerMenu(appName: effectiveApp, path: triggerRequest.path, background: triggerRequest.background ?? false)

        if response.success {
            return try encodeJSON(response)
        } else {
            return try encodeJSON(response, status: .badRequest)
        }
    }

    // MARK: - Helpers

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
