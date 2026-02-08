import Foundation
import Hummingbird

/// Handler for /wait endpoint
public struct WaitRoute: Sendable {

    public init() {}

    /// Handles POST /wait request
    /// Body: { "title": string?, "role": string?, "pid": number?, "timeout_ms": number?, "poll_interval_ms": number?, "condition": string? }
    @MainActor
    public func handle(_ request: Request, context: some RequestContext) async throws -> Response {
        // Decode request body
        let waitRequest: WaitRequest
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let body = try await request.body.collect(upTo: 1024 * 10)
            waitRequest = try decoder.decode(WaitRequest.self, from: Data(buffer: body))
        } catch {
            return try errorResponse(message: "Invalid request body: \(error.localizedDescription)", code: 400)
        }

        // Validate that at least one search criteria is provided
        if waitRequest.title == nil && waitRequest.titleContains == nil && waitRequest.role == nil && waitRequest.label == nil {
            return try errorResponse(message: "At least one search criteria required (title, titleContains, role, or label)", code: 400)
        }

        // Set defaults
        let timeoutMs = waitRequest.timeoutMs ?? 5000
        let pollIntervalMs = waitRequest.pollIntervalMs ?? 100
        let condition = waitRequest.condition ?? .exists

        // Validate timeouts
        guard timeoutMs > 0 && timeoutMs <= 60000 else {
            return try errorResponse(message: "timeout_ms must be between 1 and 60000", code: 400)
        }
        guard pollIntervalMs > 0 && pollIntervalMs <= 5000 else {
            return try errorResponse(message: "poll_interval_ms must be between 1 and 5000", code: 400)
        }

        // Build query
        let query = ElementQuery(
            role: waitRequest.role,
            titleContains: waitRequest.titleContains,
            title: waitRequest.title,
            labelContains: waitRequest.label,
            maxResults: 1
        )

        let accessibilityService = AccessibilityService.shared
        let startTime = Date()
        var waitedMs = 0
        var lastElement: UIElementInfo?

        // Poll loop
        while waitedMs < timeoutMs {
            let findResult = accessibilityService.findElements(pid: waitRequest.pid, query: query)
            let elementFound = findResult.success && (findResult.elements?.isEmpty == false)
            let element = findResult.elements?.first
            lastElement = element

            // Check condition
            let conditionMet: Bool
            switch condition {
            case .exists:
                conditionMet = elementFound
            case .notExists:
                conditionMet = !elementFound
            case .enabled:
                conditionMet = elementFound && (element?.isEnabled == true)
            case .focused:
                conditionMet = elementFound && (element?.isFocused == true)
            }

            if conditionMet {
                let elementInfo: ClickedElementInfo?
                if let element = element {
                    elementInfo = ClickedElementInfo(
                        role: element.role,
                        title: element.title,
                        label: element.label,
                        frame: element.frame.map { ElementFrameInfo(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
                    )
                } else {
                    elementInfo = nil
                }

                let response = WaitResponse(
                    success: true,
                    conditionMet: true,
                    element: elementInfo,
                    waitedMs: waitedMs
                )
                return try encodeJSON(response)
            }

            // Wait for poll interval
            try await Task.sleep(nanoseconds: UInt64(pollIntervalMs) * 1_000_000)
            waitedMs = Int(Date().timeIntervalSince(startTime) * 1000)
        }

        // Timeout reached
        let elementInfo: ClickedElementInfo?
        if let element = lastElement {
            elementInfo = ClickedElementInfo(
                role: element.role,
                title: element.title,
                label: element.label,
                frame: element.frame.map { ElementFrameInfo(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
            )
        } else {
            elementInfo = nil
        }

        let response = WaitResponse(
            success: true,
            conditionMet: false,
            element: elementInfo,
            waitedMs: waitedMs,
            error: "Timeout: condition '\(condition.rawValue)' not met within \(timeoutMs)ms"
        )
        return try encodeJSON(response)
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
