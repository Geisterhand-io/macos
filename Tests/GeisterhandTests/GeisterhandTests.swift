import Testing
@testable import GeisterhandCore

@Suite("Geisterhand Core Tests")
struct GeisterhandTests {

    @Test("KeyCodeMap returns correct key codes for letters")
    func keyCodeMapLetters() {
        #expect(KeyCodeMap.keyCode(for: "a") == 0)
        #expect(KeyCodeMap.keyCode(for: "A") == 0)
        #expect(KeyCodeMap.keyCode(for: "s") == 1)
        #expect(KeyCodeMap.keyCode(for: "z") == 6)
    }

    @Test("KeyCodeMap returns correct key codes for special keys")
    func keyCodeMapSpecialKeys() {
        #expect(KeyCodeMap.keyCode(for: "return") != nil)
        #expect(KeyCodeMap.keyCode(for: "enter") == KeyCodeMap.keyCode(for: "return"))
        #expect(KeyCodeMap.keyCode(for: "tab") != nil)
        #expect(KeyCodeMap.keyCode(for: "space") != nil)
        #expect(KeyCodeMap.keyCode(for: "escape") != nil)
        #expect(KeyCodeMap.keyCode(for: "esc") == KeyCodeMap.keyCode(for: "escape"))
    }

    @Test("KeyCodeMap returns correct key codes for function keys")
    func keyCodeMapFunctionKeys() {
        #expect(KeyCodeMap.keyCode(for: "f1") != nil)
        #expect(KeyCodeMap.keyCode(for: "f12") != nil)
        #expect(KeyCodeMap.keyCode(for: "F1") == KeyCodeMap.keyCode(for: "f1"))
    }

    @Test("KeyCodeMap returns nil for unknown keys")
    func keyCodeMapUnknownKeys() {
        #expect(KeyCodeMap.keyCode(for: "unknownkey") == nil)
        #expect(KeyCodeMap.keyCode(for: "") == nil)
    }

    @Test("KeyCodeMap handles character mapping")
    func keyCodeMapCharacters() {
        // Lowercase letter
        if let (keyCode, needsShift) = KeyCodeMap.keyCodeForCharacter("a") {
            #expect(keyCode == 0)
            #expect(needsShift == false)
        } else {
            Issue.record("Failed to get key code for 'a'")
        }

        // Uppercase letter
        if let (keyCode, needsShift) = KeyCodeMap.keyCodeForCharacter("A") {
            #expect(keyCode == 0)
            #expect(needsShift == true)
        } else {
            Issue.record("Failed to get key code for 'A'")
        }

        // Number
        if let (keyCode, needsShift) = KeyCodeMap.keyCodeForCharacter("1") {
            #expect(keyCode == KeyCodeMap.keyCode(for: "1"))
            #expect(needsShift == false)
        } else {
            Issue.record("Failed to get key code for '1'")
        }

        // Shift character
        if let (keyCode, needsShift) = KeyCodeMap.keyCodeForCharacter("!") {
            #expect(keyCode == KeyCodeMap.keyCode(for: "1"))
            #expect(needsShift == true)
        } else {
            Issue.record("Failed to get key code for '!'")
        }
    }

    @Test("API Models encode and decode correctly")
    func apiModelsCodable() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Test ClickRequest
        let clickRequest = ClickRequest(x: 100, y: 200, button: .right, clickCount: 2, modifiers: [.cmd, .shift])
        let clickData = try encoder.encode(clickRequest)
        let decodedClick = try decoder.decode(ClickRequest.self, from: clickData)
        #expect(decodedClick.x == 100)
        #expect(decodedClick.y == 200)
        #expect(decodedClick.button == .right)
        #expect(decodedClick.clickCount == 2)

        // Test TypeRequest
        let typeRequest = TypeRequest(text: "Hello World", delayMs: 50)
        let typeData = try encoder.encode(typeRequest)
        let decodedType = try decoder.decode(TypeRequest.self, from: typeData)
        #expect(decodedType.text == "Hello World")
        #expect(decodedType.delayMs == 50)

        // Test KeyRequest
        let keyRequest = KeyRequest(key: "s", modifiers: [.cmd])
        let keyData = try encoder.encode(keyRequest)
        let decodedKey = try decoder.decode(KeyRequest.self, from: keyData)
        #expect(decodedKey.key == "s")
        #expect(decodedKey.modifiers?.contains(.cmd) == true)

        // Test ScrollRequest
        let scrollRequest = ScrollRequest(x: 400, y: 300, deltaX: 0, deltaY: -100)
        let scrollData = try encoder.encode(scrollRequest)
        let decodedScroll = try decoder.decode(ScrollRequest.self, from: scrollData)
        #expect(decodedScroll.x == 400)
        #expect(decodedScroll.y == 300)
        #expect(decodedScroll.deltaY == -100)
    }

    @Test("StatusResponse structure is correct")
    func statusResponseStructure() throws {
        let status = StatusResponse(
            status: "ok",
            version: "1.0.0",
            serverRunning: true,
            permissions: PermissionStatus(accessibility: true, screenRecording: true),
            frontmostApp: AppInfo(name: "Finder", bundleIdentifier: "com.apple.finder", processIdentifier: 123),
            screenSize: ScreenSize(width: 1920, height: 1080)
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(status)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(StatusResponse.self, from: data)

        #expect(decoded.status == "ok")
        #expect(decoded.version == "1.0.0")
        #expect(decoded.serverRunning == true)
        #expect(decoded.permissions.accessibility == true)
        #expect(decoded.permissions.screenRecording == true)
        #expect(decoded.frontmostApp?.name == "Finder")
        #expect(decoded.screenSize.width == 1920)
        #expect(decoded.screenSize.height == 1080)
    }

    @Test("ScreenSize model works correctly")
    func screenSizeModel() {
        let size = ScreenSize(width: 2560, height: 1440)
        #expect(size.width == 2560)
        #expect(size.height == 1440)
    }

    @Test("PermissionManager singleton exists")
    func permissionManagerSingleton() {
        let manager = PermissionManager.shared
        #expect(manager === PermissionManager.shared)
    }

    @Test("ImageEncoder exists")
    func imageEncoderExists() {
        let encoder = ImageEncoder()
        #expect(type(of: encoder) == ImageEncoder.self)
    }
}
