import Testing
import Foundation
import Hummingbird
import HummingbirdTesting
import Logging
@testable import GeisterhandCore

// MARK: - Test Helpers

private let quietLogger: Logger = {
    var logger = Logger(label: "test")
    logger.logLevel = .critical
    return logger
}()

private func withTestApp(_ test: @Sendable (any TestClientProtocol) async throws -> Void) async throws {
    let router = buildGeisterhandRouter(targetApp: nil, logger: quietLogger)
    let app = Application(router: router, configuration: .init(), logger: quietLogger)
    try await app.test(.router) { client in
        try await test(client)
    }
}

private func jsonBody(_ dict: [String: Any]) -> ByteBuffer {
    let data = try! JSONSerialization.data(withJSONObject: dict)
    return ByteBuffer(data: data)
}

private let jsonHeaders: HTTPFields = [.contentType: "application/json"]

/// Decode a JSON response body into a dictionary
private func jsonDict(_ body: ByteBuffer) -> [String: Any]? {
    guard let data = body.getData(at: body.readerIndex, length: body.readableBytes) else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
}

// MARK: - Suite 1: Smoke Tests

@Suite("Smoke Tests")
struct SmokeTests {

    @Test("GET / returns API info with name and endpoints")
    func rootEndpoint() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(response.status == .ok)
                let dict = jsonDict(response.body)
                #expect(dict?["name"] as? String == "Geisterhand")
                let endpoints = dict?["endpoints"] as? [[String: Any]]
                #expect(endpoints != nil)
                #expect((endpoints?.count ?? 0) > 0)
            }
        }
    }

    @Test("GET /health returns ok status")
    func healthEndpoint() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/health", method: .get) { response in
                #expect(response.status == .ok)
                let dict = jsonDict(response.body)
                #expect(dict?["status"] as? String == "ok")
            }
        }
    }

    @Test("GET /status returns decodable StatusResponse")
    func statusEndpoint() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/status", method: .get) { response in
                #expect(response.status == .ok)
                let data = response.body.getData(at: response.body.readerIndex, length: response.body.readableBytes)!
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let status = try decoder.decode(StatusResponse.self, from: data)
                #expect(status.version == StatusRoute.version)
            }
        }
    }
}

// MARK: - Suite 2: Input Validation

@Suite("Input Validation")
struct InputValidationTests {

    // MARK: POST /click

    @Test("POST /click with invalid JSON returns 400")
    func clickInvalidJSON() async throws {
        try await withTestApp { client in
            let body = ByteBuffer(string: "not json")
            try await client.execute(uri: "/click", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(response.status == .badRequest)
                let dict = jsonDict(response.body)
                #expect(dict?["error"] != nil)
            }
        }
    }

    @Test("POST /click with missing fields returns 400")
    func clickMissingFields() async throws {
        try await withTestApp { client in
            let body = jsonBody(["x": 100])
            try await client.execute(uri: "/click", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(response.status == .badRequest)
            }
        }
    }

    @Test("POST /click with negative coordinates returns 400")
    func clickNegativeCoords() async throws {
        try await withTestApp { client in
            let body = jsonBody(["x": -1, "y": -1])
            try await client.execute(uri: "/click", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(response.status == .badRequest)
                let dict = jsonDict(response.body)
                let error = dict?["error"] as? String ?? ""
                #expect(error.contains("non-negative"))
            }
        }
    }

    // MARK: POST /type

    @Test("POST /type with empty text returns 400")
    func typeEmptyText() async throws {
        try await withTestApp { client in
            let body = jsonBody(["text": ""])
            try await client.execute(uri: "/type", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(response.status == .badRequest)
                let dict = jsonDict(response.body)
                let error = dict?["error"] as? String ?? ""
                #expect(error.contains("empty"))
            }
        }
    }

    @Test("POST /type with invalid mode returns 400")
    func typeInvalidMode() async throws {
        try await withTestApp { client in
            let body = jsonBody(["text": "hello", "mode": "invalid"])
            try await client.execute(uri: "/type", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(response.status == .badRequest)
                let dict = jsonDict(response.body)
                let error = dict?["error"] as? String ?? ""
                #expect(error.contains("invalid") || error.contains("Invalid"))
            }
        }
    }

    // MARK: POST /scroll

    @Test("POST /scroll with zero deltas returns 400")
    func scrollZeroDeltas() async throws {
        try await withTestApp { client in
            let body = jsonBody(["x": 100, "y": 100, "delta_x": 0, "delta_y": 0])
            try await client.execute(uri: "/scroll", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(response.status == .badRequest)
                let dict = jsonDict(response.body)
                let error = dict?["error"] as? String ?? ""
                #expect(error.contains("non-zero"))
            }
        }
    }

    @Test("POST /scroll without coordinates or target returns 400")
    func scrollMissingCoords() async throws {
        try await withTestApp { client in
            let body = jsonBody(["delta_y": -50])
            try await client.execute(uri: "/scroll", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(response.status == .badRequest)
                let dict = jsonDict(response.body)
                let error = dict?["error"] as? String ?? ""
                #expect(error.contains("required") || error.contains("coordinates"))
            }
        }
    }

    // MARK: POST /click/element

    @Test("POST /click/element with no search criteria returns 400")
    func clickElementNoCriteria() async throws {
        try await withTestApp { client in
            let body = jsonBody([:])
            try await client.execute(uri: "/click/element", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(response.status == .badRequest)
                let dict = jsonDict(response.body)
                let error = dict?["error"] as? String ?? ""
                #expect(error.contains("criteria"))
            }
        }
    }

    // MARK: POST /accessibility/action

    @Test("POST /accessibility/action with setValue but no value returns 400")
    func actionSetValueNoValue() async throws {
        try await withTestApp { client in
            let body = jsonBody([
                "path": ["pid": 1, "path": [0]],
                "action": "setValue"
            ] as [String: Any])
            try await client.execute(uri: "/accessibility/action", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(response.status == .badRequest)
                let dict = jsonDict(response.body)
                let error = dict?["error"] as? String ?? ""
                #expect(error.contains("value") || error.contains("setValue"))
            }
        }
    }

    // MARK: GET /accessibility/elements

    @Test("GET /accessibility/elements with no search criteria returns 400")
    func findElementsNoCriteria() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/accessibility/elements", method: .get) { response in
                #expect(response.status == .badRequest)
                let dict = jsonDict(response.body)
                let error = dict?["error"] as? String ?? ""
                #expect(error.contains("criteria"))
            }
        }
    }

    // MARK: GET /accessibility/element

    @Test("GET /accessibility/element without pid returns 400")
    func getElementMissingPid() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/accessibility/element?path=0,1", method: .get) { response in
                #expect(response.status == .badRequest)
                let dict = jsonDict(response.body)
                let error = dict?["error"] as? String ?? ""
                #expect(error.contains("pid"))
            }
        }
    }

    @Test("GET /accessibility/element without path returns 400")
    func getElementMissingPath() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/accessibility/element?pid=1", method: .get) { response in
                #expect(response.status == .badRequest)
                let dict = jsonDict(response.body)
                let error = dict?["error"] as? String ?? ""
                #expect(error.contains("path"))
            }
        }
    }
}

// MARK: - Suite 3: All Endpoints Respond

@Suite("All Endpoints Respond")
struct AllEndpointsRespondTests {

    @Test("GET /status returns JSON")
    func statusResponds() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/status", method: .get) { response in
                #expect(response.status == .ok)
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("GET /screenshot returns a response")
    func screenshotResponds() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/screenshot?format=base64", method: .get) { response in
                // May succeed (200 with JSON) or fail (500 with JSON error) depending on permissions
                // Either way the response should not be empty
                #expect(response.body.readableBytes > 0)
            }
        }
    }

    @Test("POST /click with valid coords returns JSON")
    func clickResponds() async throws {
        try await withTestApp { client in
            let body = jsonBody(["x": 100, "y": 100])
            try await client.execute(uri: "/click", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("POST /click/element with criteria returns JSON")
    func clickElementResponds() async throws {
        try await withTestApp { client in
            let body = jsonBody(["title": "Nonexistent", "role": "AXButton"])
            try await client.execute(uri: "/click/element", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("POST /type with valid text returns JSON")
    func typeResponds() async throws {
        try await withTestApp { client in
            let body = jsonBody(["text": "hello"])
            try await client.execute(uri: "/type", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("POST /key with valid key returns JSON")
    func keyResponds() async throws {
        try await withTestApp { client in
            let body = jsonBody(["key": "a"])
            try await client.execute(uri: "/key", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("POST /scroll with valid params returns JSON")
    func scrollResponds() async throws {
        try await withTestApp { client in
            let body = jsonBody(["x": 100, "y": 100, "delta_y": -10])
            try await client.execute(uri: "/scroll", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("POST /wait with criteria returns JSON")
    func waitResponds() async throws {
        try await withTestApp { client in
            let body = jsonBody(["title": "Nonexistent", "timeout_ms": 100])
            try await client.execute(uri: "/wait", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("GET /accessibility/tree returns JSON")
    func accessibilityTreeResponds() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/accessibility/tree", method: .get) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("GET /accessibility/elements with criteria returns JSON")
    func accessibilityElementsResponds() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/accessibility/elements?role=AXButton", method: .get) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("GET /accessibility/focused returns JSON")
    func accessibilityFocusedResponds() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/accessibility/focused", method: .get) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("POST /accessibility/action with valid body returns JSON")
    func accessibilityActionResponds() async throws {
        try await withTestApp { client in
            let body = jsonBody([
                "path": ["pid": 1, "path": [0]],
                "action": "press"
            ] as [String: Any])
            try await client.execute(uri: "/accessibility/action", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("GET /menu returns JSON")
    func menuGetResponds() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/menu?app=Finder", method: .get) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("POST /menu with body returns JSON")
    func menuPostResponds() async throws {
        try await withTestApp { client in
            let body = jsonBody(["app": "Finder", "path": ["File", "New Window"]])
            try await client.execute(uri: "/menu", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("GET /accessibility/element with params returns JSON")
    func accessibilityElementResponds() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/accessibility/element?pid=1&path=0", method: .get) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }
}

// MARK: - Suite 4: New Feature Validation

@Suite("New Feature Validation")
struct NewFeatureValidationTests {

    @Test("POST /type with mode=keys is accepted")
    func typeKeysMode() async throws {
        try await withTestApp { client in
            let body = jsonBody(["text": "hi", "mode": "keys"])
            try await client.execute(uri: "/type", method: .post, headers: jsonHeaders, body: body) { response in
                // Should not be 400 — mode is valid
                #expect(response.status != .badRequest)
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("POST /type with mode=replace is accepted")
    func typeReplaceMode() async throws {
        try await withTestApp { client in
            let body = jsonBody(["text": "hi", "mode": "replace"])
            try await client.execute(uri: "/type", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(response.status != .badRequest)
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("POST /type with invalid mode returns 400 with specific message")
    func typeInvalidModeMessage() async throws {
        try await withTestApp { client in
            let body = jsonBody(["text": "hi", "mode": "bogus"])
            try await client.execute(uri: "/type", method: .post, headers: jsonHeaders, body: body) { response in
                #expect(response.status == .badRequest)
                let dict = jsonDict(response.body)
                let error = dict?["error"] as? String ?? ""
                #expect(error.contains("'replace'") || error.contains("replace"))
                #expect(error.contains("'keys'") || error.contains("keys"))
            }
        }
    }

    @Test("GET /accessibility/tree with rootPath param is accepted")
    func treeWithRootPath() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/accessibility/tree?rootPath=0,1,2", method: .get) { response in
                // Should return JSON (may fail with accessibility error, but not a routing/param error)
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("GET /accessibility/element with childDepth param returns JSON")
    func elementWithChildDepth() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/accessibility/element?pid=1&path=0&childDepth=2", method: .get) { response in
                #expect(jsonDict(response.body) != nil)
            }
        }
    }

    @Test("GET / endpoints list includes /accessibility/element")
    func rootEndpointsIncludeElement() async throws {
        try await withTestApp { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(response.status == .ok)
                let dict = jsonDict(response.body)
                let endpoints = dict?["endpoints"] as? [[String: Any]] ?? []
                let paths = endpoints.compactMap { $0["path"] as? String }
                #expect(paths.contains("/accessibility/element"))
            }
        }
    }
}

// MARK: - Suite 5: New Model Serialization

@Suite("New Model Serialization")
struct NewModelSerializationTests {

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    @Test("GetElementResponse round-trips through JSON")
    func getElementResponseRoundTrip() throws {
        let response = GetElementResponse(
            success: true,
            app: AppInfo(name: "Test", bundleIdentifier: "com.test", processIdentifier: 42),
            element: UIElementInfo(
                path: ElementPath(pid: 42, path: [0, 1]),
                role: "AXButton",
                title: "OK",
                isEnabled: true,
                isFocused: false,
                actions: ["AXPress"]
            )
        )

        let data = try encoder.encode(response)
        let decoded = try decoder.decode(GetElementResponse.self, from: data)

        #expect(decoded.success == true)
        #expect(decoded.app?.name == "Test")
        #expect(decoded.element?.role == "AXButton")
        #expect(decoded.element?.title == "OK")
        #expect(decoded.element?.path.pid == 42)
        #expect(decoded.element?.path.path == [0, 1])
    }

    @Test("TypeRequest with mode field round-trips")
    func typeRequestWithMode() throws {
        let request = TypeRequest(text: "hello", mode: "keys")
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(TypeRequest.self, from: data)

        #expect(decoded.text == "hello")
        #expect(decoded.mode == "keys")
    }

    @Test("TypeRequest without mode decodes nil")
    func typeRequestWithoutMode() throws {
        let json = """
        {"text": "hello"}
        """
        let decoded = try decoder.decode(TypeRequest.self, from: Data(json.utf8))

        #expect(decoded.text == "hello")
        #expect(decoded.mode == nil)
    }

    @Test("GetCompactTreeResponse round-trips through JSON")
    func getCompactTreeResponseRoundTrip() throws {
        let response = GetCompactTreeResponse(
            success: true,
            app: AppInfo(name: "Finder", bundleIdentifier: "com.apple.finder", processIdentifier: 100),
            elements: [
                CompactElementInfo(
                    path: ElementPath(pid: 100, path: [0]),
                    role: "AXWindow",
                    title: "Documents",
                    depth: 0
                ),
                CompactElementInfo(
                    path: ElementPath(pid: 100, path: [0, 0]),
                    role: "AXButton",
                    title: "Close",
                    actions: ["AXPress"],
                    depth: 1
                )
            ],
            count: 2
        )

        let data = try encoder.encode(response)
        let decoded = try decoder.decode(GetCompactTreeResponse.self, from: data)

        #expect(decoded.success == true)
        #expect(decoded.count == 2)
        #expect(decoded.elements?.count == 2)
        #expect(decoded.elements?[0].role == "AXWindow")
        #expect(decoded.elements?[1].depth == 1)
        #expect(decoded.elements?[1].actions == ["AXPress"])
    }
}
