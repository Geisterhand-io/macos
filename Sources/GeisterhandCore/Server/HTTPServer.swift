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
    public let targetApp: TargetApp?

    public private(set) var isRunning: Bool = false

    public init(host: String = defaultHost, port: Int = defaultPort, targetApp: TargetApp? = nil, verbose: Bool = false) {
        self.host = host
        self.port = port
        self.targetApp = targetApp

        var logger = Logger(label: "com.geisterhand.server")
        logger.logLevel = verbose ? .debug : .info
        self.logger = logger
    }

    /// Find an available port by binding to port 0
    public static func findAvailablePort(host: String = defaultHost) throws -> Int {
        let socketFD = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard socketFD >= 0 else {
            throw NSError(domain: "GeisterhandServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create socket"])
        }
        defer { Darwin.close(socketFD) }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0 // Let the OS choose
        addr.sin_addr.s_addr = inet_addr(host)

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.bind(socketFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw NSError(domain: "GeisterhandServer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to bind socket"])
        }

        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let getsocknameResult = withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.getsockname(socketFD, sockaddrPtr, &addrLen)
            }
        }
        guard getsocknameResult == 0 else {
            throw NSError(domain: "GeisterhandServer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get socket name"])
        }

        return Int(UInt16(bigEndian: addr.sin_port))
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
        do {
            try await app.run()
        } catch {
            self.isRunning = false
            logger.error("Server stopped with error: \(error)")
            throw error
        }
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
        buildGeisterhandRouter(targetApp: targetApp, logger: logger)
    }
}

/// Builds the Geisterhand router with all API routes.
/// Public so integration tests can create a router without starting a full server.
public func buildGeisterhandRouter(targetApp: TargetApp?, logger: Logger) -> Router<BasicRequestContext> {
    let router = Router()

    // Add middleware
    router.middlewares.add(ErrorCatchingMiddleware(logger: logger))
    router.middlewares.add(RequestLoggingMiddleware(logger: logger))

    // Status endpoint
    let statusRoute = StatusRoute(targetApp: targetApp)
    router.get("/status") { request, context in
        try await statusRoute.handle(request, context: context)
    }

    // Screenshot endpoint
    let screenshotRoute = ScreenshotRoute(targetApp: targetApp)
    router.get("/screenshot") { request, context in
        try await screenshotRoute.handle(request, context: context)
    }

    // Click endpoint
    let clickRoute = ClickRoute(targetApp: targetApp)
    router.post("/click") { request, context in
        try await clickRoute.handle(request, context: context)
    }
    router.post("/click/element") { request, context in
        try await clickRoute.handleElement(request, context: context)
    }

    // Type endpoint
    let typeRoute = TypeRoute(targetApp: targetApp)
    router.post("/type") { request, context in
        try await typeRoute.handle(request, context: context)
    }

    // Key endpoint
    let keyRoute = KeyRoute(targetApp: targetApp)
    router.post("/key") { request, context in
        try await keyRoute.handle(request, context: context)
    }

    // Scroll endpoint
    let scrollRoute = ScrollRoute(targetApp: targetApp)
    router.post("/scroll") { request, context in
        try await scrollRoute.handle(request, context: context)
    }

    // Wait endpoint
    let waitRoute = WaitRoute(targetApp: targetApp)
    router.post("/wait") { request, context in
        try await waitRoute.handle(request, context: context)
    }

    // Accessibility endpoints
    let accessibilityRoute = AccessibilityRoute(targetApp: targetApp)
    router.get("/accessibility/tree") { request, context in
        try await accessibilityRoute.handleTree(request, context: context)
    }
    router.get("/accessibility/element") { request, context in
        try await accessibilityRoute.handleElement(request, context: context)
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
    let menuRoute = MenuRoute(targetApp: targetApp)
    router.get("/menu") { request, context in
        try await menuRoute.handleGet(request, context: context)
    }
    router.post("/menu") { request, context in
        try await menuRoute.handleTrigger(request, context: context)
    }

    // Quit endpoint (for on-demand mode)
    router.post("/quit") { _, _ in
        // Schedule exit after response is sent
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            exit(0)
        }
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: ByteBuffer(string: "{\"success\":true,\"message\":\"Server shutting down\"}"))
        )
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
                {"method": "GET", "path": "/accessibility/tree", "description": "Get UI element hierarchy (supports ?format=compact&rootPath=0,1,2)"},
                {"method": "GET", "path": "/accessibility/element", "description": "Get single element by path (?pid=X&path=0,1,2&childDepth=1)"},
                {"method": "GET", "path": "/accessibility/elements", "description": "Find elements by criteria"},
                {"method": "GET", "path": "/accessibility/focused", "description": "Get focused element"},
                {"method": "POST", "path": "/accessibility/action", "description": "Perform action on element"},
                {"method": "GET", "path": "/menu", "description": "Get application menu structure"},
                {"method": "POST", "path": "/menu", "description": "Trigger menu item by path"},
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

// MARK: - Server Manager (for use from non-async contexts)

/// Manages the Geisterhand server lifecycle
public final class ServerManager: @unchecked Sendable {
    public static let shared = ServerManager()

    private var server: GeisterhandServer?
    private var serverTask: Task<Void, Error>?
    private let lock = NSLock()

    private init() {}

    /// Starts the server in a background task
    public func startServer(host: String = GeisterhandServer.defaultHost, port: Int = GeisterhandServer.defaultPort, targetApp: TargetApp? = nil, verbose: Bool = false) {
        lock.lock()
        defer { lock.unlock() }

        guard serverTask == nil else {
            print("Server task already exists")
            return
        }

        let newServer = GeisterhandServer(host: host, port: port, targetApp: targetApp, verbose: verbose)
        self.server = newServer

        serverTask = Task {
            do {
                try await newServer.start()
            } catch {
                print("Server error: \(error)")
                throw error
            }
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
    public func restartServer(host: String = GeisterhandServer.defaultHost, port: Int = GeisterhandServer.defaultPort, targetApp: TargetApp? = nil, verbose: Bool = false) {
        stopServer()

        // Small delay to ensure clean shutdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startServer(host: host, port: port, targetApp: targetApp, verbose: verbose)
        }
    }
}

// MARK: - Middleware

/// Catches unhandled errors in route handlers and returns JSON 500 responses
struct ErrorCatchingMiddleware<Context: RequestContext>: RouterMiddleware {
    let logger: Logger

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        do {
            return try await next(request, context)
        } catch {
            logger.error("Unhandled error: \(error) for \(request.method) \(request.uri)")
            let body = "{\"error\":\"Internal server error\",\"code\":500}"
            return Response(
                status: .internalServerError,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: ByteBuffer(string: body))
            )
        }
    }
}

/// Logs request method/path and response status/duration at debug level
struct RequestLoggingMiddleware<Context: RequestContext>: RouterMiddleware {
    let logger: Logger

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        let start = ContinuousClock.now
        logger.debug("→ \(request.method) \(request.uri)")
        let response = try await next(request, context)
        let duration = ContinuousClock.now - start
        logger.debug("← \(response.status.code) \(request.method) \(request.uri) (\(duration))")
        return response
    }
}
