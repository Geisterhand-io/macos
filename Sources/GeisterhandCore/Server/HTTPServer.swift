import Foundation
import Hummingbird
import Logging

/// Geisterhand HTTP server for automation API
public actor GeisterhandServer {
    public static let defaultPort: Int = 7676
    public static let defaultHost: String = "127.0.0.1"

    private var application: Application<RouterResponder<BasicRequestContext>>?
    private let host: String
    private let port: Int
    private let logger: Logger

    public private(set) var isRunning: Bool = false

    public init(host: String = defaultHost, port: Int = defaultPort) {
        self.host = host
        self.port = port

        var logger = Logger(label: "com.geisterhand.server")
        logger.logLevel = .info
        self.logger = logger
    }

    /// Starts the HTTP server
    public func start() async throws {
        guard !isRunning else {
            logger.warning("Server is already running")
            return
        }

        logger.info("Starting Geisterhand server on \(host):\(port)")

        let router = buildRouter()

        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname(host, port: port),
                serverName: "Geisterhand"
            ),
            logger: logger
        )

        self.application = app
        self.isRunning = true

        // Start the server
        try await app.run()
    }

    /// Stops the HTTP server
    public func stop() {
        guard isRunning else {
            logger.warning("Server is not running")
            return
        }

        logger.info("Stopping Geisterhand server")

        self.application = nil
        self.isRunning = false
    }

    /// Builds the router with all API routes
    private func buildRouter() -> Router<BasicRequestContext> {
        let router = Router()

        // Status endpoint
        let statusRoute = StatusRoute()
        router.get("/status") { request, context in
            try await statusRoute.handle(request, context: context)
        }

        // Screenshot endpoint
        let screenshotRoute = ScreenshotRoute()
        router.get("/screenshot") { request, context in
            try await screenshotRoute.handle(request, context: context)
        }

        // Click endpoint
        let clickRoute = ClickRoute()
        router.post("/click") { request, context in
            try await clickRoute.handle(request, context: context)
        }
        router.post("/click/element") { request, context in
            try await clickRoute.handleElement(request, context: context)
        }

        // Type endpoint
        let typeRoute = TypeRoute()
        router.post("/type") { request, context in
            try await typeRoute.handle(request, context: context)
        }

        // Key endpoint
        let keyRoute = KeyRoute()
        router.post("/key") { request, context in
            try await keyRoute.handle(request, context: context)
        }

        // Scroll endpoint
        let scrollRoute = ScrollRoute()
        router.post("/scroll") { request, context in
            try await scrollRoute.handle(request, context: context)
        }

        // Wait endpoint
        let waitRoute = WaitRoute()
        router.post("/wait") { request, context in
            try await waitRoute.handle(request, context: context)
        }

        // Accessibility endpoints
        let accessibilityRoute = AccessibilityRoute()
        router.get("/accessibility/tree") { request, context in
            try await accessibilityRoute.handleTree(request, context: context)
        }
        router.get("/accessibility/elements") { request, context in
            try await accessibilityRoute.handleFindElements(request, context: context)
        }
        router.get("/accessibility/focused") { request, context in
            try await accessibilityRoute.handleFocused(request, context: context)
        }
        router.post("/accessibility/action") { request, context in
            try await accessibilityRoute.handleAction(request, context: context)
        }

        // Menu endpoints
        let menuRoute = MenuRoute()
        router.get("/menu") { request, context in
            try await menuRoute.handleGet(request, context: context)
        }
        router.post("/menu") { request, context in
            try await menuRoute.handleTrigger(request, context: context)
        }

        // Health check (alias)
        router.get("/health") { _, _ in
            Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: ByteBuffer(string: "{\"status\":\"ok\"}"))
            )
        }

        // Root endpoint with API info
        router.get("/") { _, _ in
            let info = """
            {
                "name": "Geisterhand",
                "version": "\(StatusRoute.version)",
                "endpoints": [
                    {"method": "GET", "path": "/status", "description": "Health check and system info"},
                    {"method": "GET", "path": "/screenshot", "description": "Capture screen (supports ?app=AppName or ?windowId=123)"},
                    {"method": "POST", "path": "/click", "description": "Click at coordinates"},
                    {"method": "POST", "path": "/click/element", "description": "Click element by title/role/label"},
                    {"method": "POST", "path": "/type", "description": "Type text"},
                    {"method": "POST", "path": "/key", "description": "Press key with modifiers"},
                    {"method": "POST", "path": "/scroll", "description": "Scroll at position"},
                    {"method": "POST", "path": "/wait", "description": "Wait for element to appear/disappear"},
                    {"method": "GET", "path": "/accessibility/tree", "description": "Get UI element hierarchy (supports ?format=compact)"},
                    {"method": "GET", "path": "/accessibility/elements", "description": "Find elements by criteria"},
                    {"method": "GET", "path": "/accessibility/focused", "description": "Get focused element"},
                    {"method": "POST", "path": "/accessibility/action", "description": "Perform action on element"},
                    {"method": "GET", "path": "/menu", "description": "Get application menu structure"},
                    {"method": "POST", "path": "/menu", "description": "Trigger menu item by path"}
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
}

// MARK: - Server Manager (for use from non-async contexts)

/// Manages the Geisterhand server lifecycle
public final class ServerManager: @unchecked Sendable {
    public static let shared = ServerManager()

    private var server: GeisterhandServer?
    private var serverTask: Task<Void, Error>?
    private let lock = NSLock()

    private init() {}

    /// Starts the server in a background task
    public func startServer(host: String = GeisterhandServer.defaultHost, port: Int = GeisterhandServer.defaultPort) {
        lock.lock()
        defer { lock.unlock() }

        guard serverTask == nil else {
            print("Server task already exists")
            return
        }

        let newServer = GeisterhandServer(host: host, port: port)
        self.server = newServer

        serverTask = Task {
            try await newServer.start()
        }
    }

    /// Stops the server
    public func stopServer() {
        lock.lock()
        defer { lock.unlock() }

        serverTask?.cancel()
        serverTask = nil
        server = nil
    }

    /// Returns whether the server is running
    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return serverTask != nil && !serverTask!.isCancelled
    }

    /// Restarts the server
    public func restartServer(host: String = GeisterhandServer.defaultHost, port: Int = GeisterhandServer.defaultPort) {
        stopServer()

        // Small delay to ensure clean shutdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startServer(host: host, port: port)
        }
    }
}
