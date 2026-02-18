import Foundation
import Hummingbird

/// Handler for /accessibility/* endpoints
public struct AccessibilityRoute: Sendable {
    let targetApp: TargetApp?

    public init(targetApp: TargetApp? = nil) {
        self.targetApp = targetApp
    }

    // MARK: - GET /accessibility/tree

    /// Handles GET /accessibility/tree request
    /// Query params:
    /// - pid: Process ID (optional, uses frontmost app if not specified)
    /// - maxDepth: Maximum tree depth (optional, default: 5)
    /// - format: Output format - "tree" (default) or "compact" (flattened list)
    /// - includeActions: Include actions in compact format (default: true)
    /// - rootPath: Comma-separated child indices to scope to a subtree (e.g., "0,1,2")
    @MainActor
    public func handleTree(_ request: Request, context: some RequestContext) async throws -> Response {
        let service = AccessibilityService.shared

        // Parse query parameters
        let pid = request.uri.queryParameters.get("pid").flatMap { Int32($0) } ?? targetApp?.pid
        let maxDepth = request.uri.queryParameters.get("maxDepth").flatMap { Int($0) }
        let format = request.uri.queryParameters.get("format") ?? "tree"
        let includeActions = request.uri.queryParameters.get("includeActions").flatMap { $0.lowercased() != "false" } ?? true
        let rootPath = request.uri.queryParameters.get("rootPath").map { param in
            param.split(separator: ",").compactMap { Int($0) }
        }

        if format.lowercased() == "compact" {
            // Return flattened compact format
            let response = service.getCompactTree(pid: pid, maxDepth: maxDepth, includeActions: includeActions, rootPath: rootPath)

            if response.success {
                return try encodeJSON(response)
            } else {
                return try encodeJSON(response, status: .badRequest)
            }
        } else {
            // Return nested tree format (default)
            let response = service.getTree(pid: pid, maxDepth: maxDepth, rootPath: rootPath)

            if response.success {
                return try encodeJSON(response)
            } else {
                return try encodeJSON(response, status: .badRequest)
            }
        }
    }

    // MARK: - GET /accessibility/element

    /// Handles GET /accessibility/element request
    /// Query params:
    /// - pid: Process ID (required)
    /// - path: Comma-separated child indices (e.g., "0,1,2")
    /// - childDepth: How many levels of children to include (default: 0)
    @MainActor
    public func handleElement(_ request: Request, context: some RequestContext) async throws -> Response {
        let service = AccessibilityService.shared

        guard let pidStr = request.uri.queryParameters.get("pid"), let pid = Int32(pidStr) else {
            return try errorResponse(message: "Missing or invalid 'pid' parameter", code: 400)
        }

        guard let pathStr = request.uri.queryParameters.get("path") else {
            return try errorResponse(message: "Missing 'path' parameter (comma-separated indices, e.g., '0,1,2')", code: 400)
        }

        let path = pathStr.split(separator: ",").compactMap { Int($0) }
        let childDepth = request.uri.queryParameters.get("childDepth").flatMap { Int($0) } ?? 0

        let response = service.getElement(pid: pid, path: path, childDepth: childDepth)

        if response.success {
            return try encodeJSON(response)
        } else {
            return try encodeJSON(response, status: .badRequest)
        }
    }

    // MARK: - GET /accessibility/elements

    /// Handles GET /accessibility/elements request
    /// Query params: pid, role, title, titleContains, labelContains, valueContains, maxResults
    @MainActor
    public func handleFindElements(_ request: Request, context: some RequestContext) async throws -> Response {
        let service = AccessibilityService.shared

        // Parse query parameters
        let pid = request.uri.queryParameters.get("pid").flatMap { Int32($0) } ?? targetApp?.pid
        let role = request.uri.queryParameters.get("role")
        let title = request.uri.queryParameters.get("title")
        let titleContains = request.uri.queryParameters.get("titleContains")
        let labelContains = request.uri.queryParameters.get("labelContains")
        let valueContains = request.uri.queryParameters.get("valueContains")
        let maxResults = request.uri.queryParameters.get("maxResults").flatMap { Int($0) }

        // Build query
        let query = ElementQuery(
            role: role,
            titleContains: titleContains,
            title: title,
            labelContains: labelContains,
            valueContains: valueContains,
            maxResults: maxResults
        )

        // Validate that at least one search criteria is provided
        if role == nil && title == nil && titleContains == nil && labelContains == nil && valueContains == nil {
            return try errorResponse(message: "At least one search criteria required (role, title, titleContains, labelContains, or valueContains)", code: 400)
        }

        // Find elements
        let response = service.findElements(pid: pid, query: query)

        if response.success {
            return try encodeJSON(response)
        } else {
            return try encodeJSON(response, status: .badRequest)
        }
    }

    // MARK: - GET /accessibility/focused

    /// Handles GET /accessibility/focused request
    /// Query params: pid (optional)
    @MainActor
    public func handleFocused(_ request: Request, context: some RequestContext) async throws -> Response {
        let service = AccessibilityService.shared

        // Parse query parameters
        let pid = request.uri.queryParameters.get("pid").flatMap { Int32($0) } ?? targetApp?.pid

        // Get focused element
        let response = service.getFocusedElement(pid: pid)

        if response.success {
            return try encodeJSON(response)
        } else {
            return try encodeJSON(response, status: .badRequest)
        }
    }

    // MARK: - POST /accessibility/action

    /// Handles POST /accessibility/action request
    /// Body: { "path": { "pid": number, "path": [number] }, "action": string, "value": string? }
    @MainActor
    public func handleAction(_ request: Request, context: some RequestContext) async throws -> Response {
        let service = AccessibilityService.shared

        // Decode request body
        let actionRequest: ActionRequest
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let body = try await request.body.collect(upTo: 1024 * 10) // 10KB limit
            actionRequest = try decoder.decode(ActionRequest.self, from: Data(buffer: body))
        } catch {
            return try errorResponse(message: "Invalid request body: \(error.localizedDescription)", code: 400)
        }

        // Validate setValue requires a value
        if actionRequest.action == .setValue && (actionRequest.value == nil || actionRequest.value?.isEmpty == true) {
            return try errorResponse(message: "setValue action requires a non-empty 'value' parameter", code: 400)
        }

        // Perform action
        let response = service.performAction(
            path: actionRequest.path,
            action: actionRequest.action,
            value: actionRequest.value
        )

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
