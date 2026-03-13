import Foundation
import Hummingbird
import Logging
import ImageIO

/// Builds a router for simulator mode.
/// - Screenshot: uses `xcrun simctl io booted screenshot` (clean iOS content)
/// - Click/Scroll: translates iOS logical coordinates → screen-absolute CGEvent
/// - Type/Key: CGEvent forwarding to the focused Simulator window
public func buildSimulatorRouter(logger: Logger) -> Router<BasicRequestContext> {
    let router = Router()

    // Middleware
    router.middlewares.add(ErrorCatchingMiddleware(logger: logger))
    router.middlewares.add(RequestLoggingMiddleware(logger: logger))

    let simService = SimulatorService.shared

    // ── Status ──────────────────────────────────────────────
    router.get("/status") { _, _ in
        let deviceInfo = try? await simService.bootedDeviceInfo()
        let mapping = try? await simService.computeCoordinateMapping()
        let body: [String: Any] = [
            "mode": "simulator",
            "device": deviceInfo.map { ["name": $0.name, "udid": $0.udid, "runtime": $0.runtime] } as Any,
            "ios_screen": mapping.map { ["width": $0.iosWidth, "height": $0.iosHeight] } as Any,
            "scale": mapping?.scale as Any,
            "version": StatusRoute.version,
        ]
        let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(data: data))
        )
    }

    // ── Screenshot (simctl – clean iOS content) ─────────────
    router.get("/screenshot") { request, _ in
        let format = request.uri.queryParameters.get("format") ?? "png"
        let pngData = try await simService.screenshot()

        switch format.lowercased() {
        case "base64":
            let base64 = pngData.base64EncodedString()
            // Get dimensions from the PNG
            var width = 0, height = 0
            if let src = CGImageSourceCreateWithData(pngData as CFData, nil),
               let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                width = img.width
                height = img.height
            }
            let resp = ScreenshotResponse(
                success: true,
                format: "base64",
                width: width,
                height: height,
                data: base64
            )
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let json = try encoder.encode(resp)
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: ByteBuffer(data: json))
            )
        default:
            return Response(
                status: .ok,
                headers: [.contentType: "image/png"],
                body: .init(byteBuffer: ByteBuffer(data: pngData))
            )
        }
    }

    // ── Click (iOS coordinates → CGEvent) ───────────────────
    router.post("/click") { request, _ in
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let body = try await request.body.collect(upTo: 1024 * 10)
        let clickRequest = try decoder.decode(ClickRequest.self, from: Data(buffer: body))

        // Compute mapping and translate
        let mapping = try await simService.computeCoordinateMapping()
        let (screenX, screenY) = await simService.iosToScreen(
            x: clickRequest.x, y: clickRequest.y, mapping: mapping
        )

        // Post CGEvent click at screen-absolute coordinates
        let mouseController = MouseController.shared
        let button = clickRequest.button ?? .left
        let clickCount = clickRequest.clickCount ?? 1
        try mouseController.click(
            x: screenX,
            y: screenY,
            button: button,
            clickCount: clickCount,
            modifiers: []
        )

        let resp = ClickResponse(success: true, x: clickRequest.x, y: clickRequest.y, button: button.rawValue)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try encoder.encode(resp)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(data: json))
        )
    }

    // ── Scroll (iOS coordinates → CGEvent) ──────────────────
    router.post("/scroll") { request, _ in
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let body = try await request.body.collect(upTo: 1024 * 10)
        let scrollRequest = try decoder.decode(ScrollRequest.self, from: Data(buffer: body))

        let iosX = scrollRequest.x ?? 0
        let iosY = scrollRequest.y ?? 0
        let deltaX = scrollRequest.deltaX ?? 0
        let deltaY = scrollRequest.deltaY ?? 0

        let mapping = try await simService.computeCoordinateMapping()
        let (screenX, screenY) = await simService.iosToScreen(
            x: iosX, y: iosY, mapping: mapping
        )

        let mouseController = MouseController.shared
        try mouseController.scroll(x: screenX, y: screenY, deltaX: deltaX, deltaY: deltaY)

        let resp = ScrollResponse(success: true, x: iosX, y: iosY, deltaX: deltaX, deltaY: deltaY)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try encoder.encode(resp)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(data: json))
        )
    }

    // ── Type (CGEvent to focused Simulator) ─────────────────
    router.post("/type") { request, _ in
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let body = try await request.body.collect(upTo: 1024 * 100)
        let typeRequest = try decoder.decode(TypeRequest.self, from: Data(buffer: body))

        let keyboardController = KeyboardController.shared
        let count = try keyboardController.type(text: typeRequest.text, delayMs: typeRequest.delayMs ?? 0)

        let resp = TypeResponse(success: true, charactersTyped: count)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try encoder.encode(resp)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(data: json))
        )
    }

    // ── Key (CGEvent to focused Simulator) ──────────────────
    router.post("/key") { request, _ in
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let body = try await request.body.collect(upTo: 1024 * 10)
        let keyRequest = try decoder.decode(KeyRequest.self, from: Data(buffer: body))

        let keyboardController = KeyboardController.shared
        let modifiers = keyRequest.modifiers ?? []
        try keyboardController.pressKey(key: keyRequest.key, modifiers: modifiers)

        let resp = KeyResponse(success: true, key: keyRequest.key, modifiers: modifiers.map { $0.rawValue })
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try encoder.encode(resp)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(data: json))
        )
    }

    // ── Quit ────────────────────────────────────────────────
    router.post("/quit") { _, _ in
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exit(0) }
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(string: "{\"success\":true,\"message\":\"Server shutting down\"}"))
        )
    }

    // ── Health ──────────────────────────────────────────────
    router.get("/health") { _, _ in
        Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(string: "{\"status\":\"ok\",\"mode\":\"simulator\"}"))
        )
    }

    // ── Root ────────────────────────────────────────────────
    router.get("/") { _, _ in
        let info = """
        {
            "name": "Geisterhand",
            "mode": "simulator",
            "version": "\(StatusRoute.version)",
            "note": "All coordinates are iOS logical points. Screenshots are clean iOS content (no simulator chrome).",
            "endpoints": [
                {"method": "GET", "path": "/status", "description": "Simulator device info and screen size"},
                {"method": "GET", "path": "/screenshot", "description": "iOS screenshot via simctl (supports ?format=base64)"},
                {"method": "POST", "path": "/click", "description": "Tap at iOS coordinates {x, y}"},
                {"method": "POST", "path": "/scroll", "description": "Scroll at iOS coordinates {x, y, delta_y}"},
                {"method": "POST", "path": "/type", "description": "Type text {text}"},
                {"method": "POST", "path": "/key", "description": "Press key {key, modifiers}"},
                {"method": "POST", "path": "/quit", "description": "Shut down the server"}
            ]
        }
        """
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(string: info))
        )
    }

    return router
}

/// Starts a Geisterhand server in simulator mode
public func startSimulatorServer(host: String, port: Int, verbose: Bool) async throws {
    var logger = Logger(label: "com.geisterhand.sim")
    logger.logLevel = verbose ? .debug : .info
    let router = buildSimulatorRouter(logger: logger)

    let app = Application(
        router: router,
        configuration: .init(
            address: .hostname(host, port: port),
            serverName: "Geisterhand-Sim"
        ),
        logger: logger
    )

    try await app.run()
}
