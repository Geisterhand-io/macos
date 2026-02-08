import Foundation
import Hummingbird
import AppKit
import ApplicationServices

/// Handler for /click endpoint
public struct ClickRoute: Sendable {

    public init() {}

    // MARK: - POST /click/element

    /// Handles POST /click/element request
    /// Body: { "title": string, "role": string?, "pid": number?, ... }
    @MainActor
    public func handleElement(_ request: Request, context: some RequestContext) async throws -> Response {
        let mouseController = MouseController.shared

        // Decode request body
        let elementRequest: ElementClickRequest
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let body = try await request.body.collect(upTo: 1024 * 10)
            elementRequest = try decoder.decode(ElementClickRequest.self, from: Data(buffer: body))
        } catch {
            return try errorResponse(message: "Invalid request body: \(error.localizedDescription)", code: 400)
        }

        // Validate that at least one search criteria is provided
        if elementRequest.title == nil && elementRequest.titleContains == nil && elementRequest.role == nil && elementRequest.label == nil {
            return try errorResponse(message: "At least one search criteria required (title, titleContains, role, or label)", code: 400)
        }

        // Build query
        let query = ElementQuery(
            role: elementRequest.role,
            titleContains: elementRequest.titleContains,
            title: elementRequest.title,
            labelContains: elementRequest.label,
            maxResults: 1
        )

        // Find the element
        let accessibilityService = AccessibilityService.shared
        let findResult = accessibilityService.findElements(pid: elementRequest.pid, query: query)

        guard findResult.success, let elements = findResult.elements, let element = elements.first else {
            let error = findResult.error ?? "No matching element found"
            let response = ElementClickResponse(success: false, error: error)
            return try encodeJSON(response, status: .badRequest)
        }

        // Get element info for response
        let elementInfo = ClickedElementInfo(
            role: element.role,
            title: element.title,
            label: element.label,
            frame: element.frame.map { ElementFrameInfo(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
        )

        // Decide whether to use accessibility action or mouse click
        let useAccessibilityAction = elementRequest.useAccessibilityAction ?? false

        if useAccessibilityAction {
            // Use AX press action
            let actionResult = accessibilityService.performAction(
                path: element.path,
                action: .press,
                value: nil
            )

            if actionResult.success {
                let response = ElementClickResponse(success: true, element: elementInfo)
                return try encodeJSON(response)
            } else {
                let response = ElementClickResponse(success: false, element: elementInfo, error: actionResult.error ?? "Action failed")
                return try encodeJSON(response, status: .internalServerError)
            }
        } else {
            // Use mouse click at center of element
            guard let frame = element.frame else {
                let response = ElementClickResponse(success: false, element: elementInfo, error: "Element has no frame")
                return try encodeJSON(response, status: .badRequest)
            }

            let centerX = frame.x + frame.width / 2
            let centerY = frame.y + frame.height / 2
            let button = elementRequest.button ?? .left

            do {
                try mouseController.click(
                    x: centerX,
                    y: centerY,
                    button: button,
                    clickCount: 1,
                    modifiers: []
                )

                let coordinates = ClickCoordinates(x: centerX, y: centerY)
                let response = ElementClickResponse(success: true, element: elementInfo, clickedAt: coordinates)
                return try encodeJSON(response)
            } catch {
                let response = ElementClickResponse(success: false, element: elementInfo, error: error.localizedDescription)
                return try encodeJSON(response, status: .internalServerError)
            }
        }
    }

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
