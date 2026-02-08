import Foundation
import Hummingbird

/// Handler for /scroll endpoint
public struct ScrollRoute: Sendable {

    public init() {}

    /// Handles POST /scroll request
    /// Body: { "x": number, "y": number, "delta_x": number, "delta_y": number }
    /// PID-targeted: { "x": 500, "y": 300, "delta_y": -100, "pid": 1234 }
    /// Element path: { "delta_y": -100, "path": {"pid": 1234, "path": [0, 0, 2]} }
    @MainActor
    public func handle(_ request: Request, context: some RequestContext) async throws -> Response {
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

        let deltaX = scrollRequest.deltaX ?? 0
        let deltaY = scrollRequest.deltaY ?? 0

        // Validate that at least one delta is provided
        guard deltaX != 0 || deltaY != 0 else {
            return try errorResponse(message: "At least one of delta_x or delta_y must be non-zero", code: 400)
        }

        if let path = scrollRequest.path {
            // Element path mode: find element frame, scroll at its center
            return try handleElementPathScroll(path: path, deltaX: deltaX, deltaY: deltaY)
        } else if let pid = scrollRequest.pid {
            // PID-targeted mode
            let x = scrollRequest.x ?? 0
            let y = scrollRequest.y ?? 0
            guard x >= 0 && y >= 0 else {
                return try errorResponse(message: "Invalid coordinates: x and y must be non-negative", code: 400)
            }
            return try handlePIDTargetedScroll(x: x, y: y, deltaX: deltaX, deltaY: deltaY, pid: pid)
        } else {
            // Standard global scroll (original behavior)
            guard let x = scrollRequest.x, let y = scrollRequest.y else {
                return try errorResponse(message: "x and y coordinates are required for non-targeted scroll", code: 400)
            }
            guard x >= 0 && y >= 0 else {
                return try errorResponse(message: "Invalid coordinates: x and y must be non-negative", code: 400)
            }
            return try handleGlobalScroll(x: x, y: y, deltaX: deltaX, deltaY: deltaY)
        }
    }

    /// Scroll at element's center coordinates using PID-targeted CGEvent
    @MainActor
    private func handleElementPathScroll(path: ElementPath, deltaX: Double, deltaY: Double) throws -> Response {
        let service = AccessibilityService.shared

        // Get the element to find its frame
        let treeResponse = service.getTree(pid: path.pid, maxDepth: 0)
        guard treeResponse.success else {
            let response = ScrollResponse(
                success: false, x: 0, y: 0, deltaX: deltaX, deltaY: deltaY,
                error: treeResponse.error ?? "Failed to access application"
            )
            return try encodeJSON(response, status: .badRequest)
        }

        // Navigate to element and get its frame
        let findResult = service.findElementFrame(path: path)
        guard let frame = findResult else {
            let response = ScrollResponse(
                success: false, x: 0, y: 0, deltaX: deltaX, deltaY: deltaY,
                error: "Element not found at path or has no frame"
            )
            return try encodeJSON(response, status: .badRequest)
        }

        let centerX = frame.x + frame.width / 2
        let centerY = frame.y + frame.height / 2

        do {
            try MouseController.shared.scroll(
                x: centerX, y: centerY,
                deltaX: deltaX, deltaY: deltaY,
                targetPid: path.pid
            )

            let response = ScrollResponse(
                success: true,
                x: centerX, y: centerY,
                deltaX: deltaX, deltaY: deltaY
            )
            return try encodeJSON(response)
        } catch {
            let response = ScrollResponse(
                success: false,
                x: centerX, y: centerY,
                deltaX: deltaX, deltaY: deltaY,
                error: error.localizedDescription
            )
            return try encodeJSON(response, status: .internalServerError)
        }
    }

    /// PID-targeted scroll at specified coordinates
    private func handlePIDTargetedScroll(x: Double, y: Double, deltaX: Double, deltaY: Double, pid: Int32) throws -> Response {
        do {
            try MouseController.shared.scroll(
                x: x, y: y,
                deltaX: deltaX, deltaY: deltaY,
                targetPid: pid
            )

            let response = ScrollResponse(
                success: true,
                x: x, y: y,
                deltaX: deltaX, deltaY: deltaY
            )
            return try encodeJSON(response)
        } catch {
            let response = ScrollResponse(
                success: false,
                x: x, y: y,
                deltaX: deltaX, deltaY: deltaY,
                error: error.localizedDescription
            )
            return try encodeJSON(response, status: .internalServerError)
        }
    }

    /// Standard global scroll (original behavior)
    private func handleGlobalScroll(x: Double, y: Double, deltaX: Double, deltaY: Double) throws -> Response {
        do {
            try MouseController.shared.scroll(
                x: x, y: y,
                deltaX: deltaX, deltaY: deltaY
            )

            let response = ScrollResponse(
                success: true,
                x: x, y: y,
                deltaX: deltaX, deltaY: deltaY
            )
            return try encodeJSON(response)
        } catch {
            let response = ScrollResponse(
                success: false,
                x: x, y: y,
                deltaX: deltaX, deltaY: deltaY,
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
