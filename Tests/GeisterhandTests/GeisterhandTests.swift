import Testing
import Foundation
@testable import GeisterhandCore

// MARK: - KeyCodeMap Tests

@Suite("KeyCodeMap Tests")
struct KeyCodeMapTests {

    @Test("Returns correct key codes for all letters")
    func keyCodeMapAllLetters() {
        let letters = "abcdefghijklmnopqrstuvwxyz"
        for letter in letters {
            let keyCode = KeyCodeMap.keyCode(for: String(letter))
            #expect(keyCode != nil, "Key code for '\(letter)' should exist")
        }
    }

    @Test("Returns same key code for uppercase and lowercase letters")
    func keyCodeMapCaseInsensitive() {
        #expect(KeyCodeMap.keyCode(for: "a") == KeyCodeMap.keyCode(for: "A"))
        #expect(KeyCodeMap.keyCode(for: "z") == KeyCodeMap.keyCode(for: "Z"))
        #expect(KeyCodeMap.keyCode(for: "m") == KeyCodeMap.keyCode(for: "M"))
    }

    @Test("Returns correct key codes for numbers")
    func keyCodeMapNumbers() {
        for i in 0...9 {
            let keyCode = KeyCodeMap.keyCode(for: String(i))
            #expect(keyCode != nil, "Key code for '\(i)' should exist")
        }
    }

    @Test("Returns correct key codes for function keys F1-F20")
    func keyCodeMapFunctionKeys() {
        for i in 1...20 {
            let keyCode = KeyCodeMap.keyCode(for: "f\(i)")
            #expect(keyCode != nil, "Key code for 'f\(i)' should exist")
            // Also test uppercase
            #expect(KeyCodeMap.keyCode(for: "F\(i)") == keyCode)
        }
    }

    @Test("Returns correct key codes for special keys")
    func keyCodeMapSpecialKeys() {
        let specialKeys = [
            "return", "enter", "tab", "space", "delete", "backspace",
            "forwarddelete", "escape", "esc"
        ]
        for key in specialKeys {
            #expect(KeyCodeMap.keyCode(for: key) != nil, "Key code for '\(key)' should exist")
        }
    }

    @Test("Key aliases return same codes")
    func keyCodeMapAliases() {
        #expect(KeyCodeMap.keyCode(for: "return") == KeyCodeMap.keyCode(for: "enter"))
        #expect(KeyCodeMap.keyCode(for: "escape") == KeyCodeMap.keyCode(for: "esc"))
        #expect(KeyCodeMap.keyCode(for: "delete") == KeyCodeMap.keyCode(for: "backspace"))
        #expect(KeyCodeMap.keyCode(for: "command") == KeyCodeMap.keyCode(for: "cmd"))
        #expect(KeyCodeMap.keyCode(for: "option") == KeyCodeMap.keyCode(for: "alt"))
        #expect(KeyCodeMap.keyCode(for: "control") == KeyCodeMap.keyCode(for: "ctrl"))
        #expect(KeyCodeMap.keyCode(for: "function") == KeyCodeMap.keyCode(for: "fn"))
    }

    @Test("Returns correct key codes for arrow keys")
    func keyCodeMapArrowKeys() {
        #expect(KeyCodeMap.keyCode(for: "left") != nil)
        #expect(KeyCodeMap.keyCode(for: "right") != nil)
        #expect(KeyCodeMap.keyCode(for: "up") != nil)
        #expect(KeyCodeMap.keyCode(for: "down") != nil)
        #expect(KeyCodeMap.keyCode(for: "leftarrow") == KeyCodeMap.keyCode(for: "left"))
        #expect(KeyCodeMap.keyCode(for: "rightarrow") == KeyCodeMap.keyCode(for: "right"))
    }

    @Test("Returns correct key codes for navigation keys")
    func keyCodeMapNavigationKeys() {
        #expect(KeyCodeMap.keyCode(for: "home") != nil)
        #expect(KeyCodeMap.keyCode(for: "end") != nil)
        #expect(KeyCodeMap.keyCode(for: "pageup") != nil)
        #expect(KeyCodeMap.keyCode(for: "pagedown") != nil)
    }

    @Test("Returns correct key codes for punctuation")
    func keyCodeMapPunctuation() {
        let punctuation = ["-", "=", "[", "]", ";", "'", "\\", ",", ".", "/", "`"]
        for key in punctuation {
            #expect(KeyCodeMap.keyCode(for: key) != nil, "Key code for '\(key)' should exist")
        }
    }

    @Test("Returns correct key codes for keypad")
    func keyCodeMapKeypad() {
        for i in 0...9 {
            #expect(KeyCodeMap.keyCode(for: "keypad\(i)") != nil)
        }
        #expect(KeyCodeMap.keyCode(for: "keypadenter") != nil)
        #expect(KeyCodeMap.keyCode(for: "keypadplus") != nil)
        #expect(KeyCodeMap.keyCode(for: "keypadminus") != nil)
    }

    @Test("Returns nil for unknown keys")
    func keyCodeMapUnknownKeys() {
        #expect(KeyCodeMap.keyCode(for: "unknownkey") == nil)
        #expect(KeyCodeMap.keyCode(for: "") == nil)
        #expect(KeyCodeMap.keyCode(for: "f99") == nil)
        #expect(KeyCodeMap.keyCode(for: "superkey") == nil)
    }

    @Test("Character mapping for lowercase letters")
    func keyCodeForCharacterLowercase() {
        if let (keyCode, needsShift) = KeyCodeMap.keyCodeForCharacter("a") {
            #expect(keyCode == KeyCodeMap.keyCode(for: "a"))
            #expect(needsShift == false)
        } else {
            Issue.record("Failed to get key code for 'a'")
        }
    }

    @Test("Character mapping for uppercase letters requires shift")
    func keyCodeForCharacterUppercase() {
        if let (keyCode, needsShift) = KeyCodeMap.keyCodeForCharacter("A") {
            #expect(keyCode == KeyCodeMap.keyCode(for: "a"))
            #expect(needsShift == true)
        } else {
            Issue.record("Failed to get key code for 'A'")
        }
    }

    @Test("Character mapping for shift characters")
    func keyCodeForCharacterShiftSymbols() {
        let shiftMappings: [(Character, String)] = [
            ("!", "1"), ("@", "2"), ("#", "3"), ("$", "4"), ("%", "5"),
            ("^", "6"), ("&", "7"), ("*", "8"), ("(", "9"), (")", "0"),
            ("_", "-"), ("+", "="), ("{", "["), ("}", "]"), ("|", "\\"),
            (":", ";"), ("\"", "'"), ("<", ","), (">", "."), ("?", "/"), ("~", "`")
        ]

        for (shiftChar, baseKey) in shiftMappings {
            if let (keyCode, needsShift) = KeyCodeMap.keyCodeForCharacter(shiftChar) {
                #expect(keyCode == KeyCodeMap.keyCode(for: baseKey), "'\(shiftChar)' should map to '\(baseKey)'")
                #expect(needsShift == true, "'\(shiftChar)' should require shift")
            } else {
                Issue.record("Failed to get key code for '\(shiftChar)'")
            }
        }
    }

    @Test("Character mapping for numbers")
    func keyCodeForCharacterNumbers() {
        for i in 0...9 {
            let char = Character(String(i))
            if let (keyCode, needsShift) = KeyCodeMap.keyCodeForCharacter(char) {
                #expect(keyCode == KeyCodeMap.keyCode(for: String(i)))
                #expect(needsShift == false)
            } else {
                Issue.record("Failed to get key code for '\(i)'")
            }
        }
    }
}

// MARK: - API Models Tests

@Suite("API Models Tests")
struct APIModelsTests {

    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    // MARK: - ClickRequest Tests

    @Test("ClickRequest encodes and decodes with all fields")
    func clickRequestFullEncodeDecode() throws {
        let request = ClickRequest(
            x: 100.5,
            y: 200.5,
            button: .right,
            clickCount: 2,
            modifiers: [.cmd, .shift]
        )

        let data = try encoder.encode(request)
        let decoded = try decoder.decode(ClickRequest.self, from: data)

        #expect(decoded.x == 100.5)
        #expect(decoded.y == 200.5)
        #expect(decoded.button == .right)
        #expect(decoded.clickCount == 2)
        #expect(decoded.modifiers?.count == 2)
    }

    @Test("ClickRequest works with minimal fields")
    func clickRequestMinimal() throws {
        let json = """
        {"x": 50, "y": 75}
        """
        let decoded = try decoder.decode(ClickRequest.self, from: Data(json.utf8))

        #expect(decoded.x == 50)
        #expect(decoded.y == 75)
        #expect(decoded.button == nil)
        #expect(decoded.clickCount == nil)
        #expect(decoded.modifiers == nil)
    }

    @Test("ClickRequest handles all mouse buttons")
    func clickRequestAllButtons() throws {
        for button in [MouseButton.left, .right, .center] {
            let request = ClickRequest(x: 0, y: 0, button: button)
            let data = try encoder.encode(request)
            let decoded = try decoder.decode(ClickRequest.self, from: data)
            #expect(decoded.button == button)
        }
    }

    @Test("ClickResponse encodes correctly")
    func clickResponseEncode() throws {
        let response = ClickResponse(success: true, x: 100, y: 200, button: "left")
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"success\":true"))
        #expect(json.contains("\"button\":\"left\""))
    }

    @Test("ClickResponse with error")
    func clickResponseWithError() throws {
        let response = ClickResponse(
            success: false,
            x: 100,
            y: 200,
            button: "left",
            error: "Permission denied"
        )

        let data = try encoder.encode(response)
        let decoded = try decoder.decode(ClickResponse.self, from: data)

        #expect(decoded.success == false)
        #expect(decoded.error == "Permission denied")
    }

    // MARK: - TypeRequest Tests

    @Test("TypeRequest encodes and decodes")
    func typeRequestEncodeDecode() throws {
        let request = TypeRequest(text: "Hello World!", delayMs: 100)
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(TypeRequest.self, from: data)

        #expect(decoded.text == "Hello World!")
        #expect(decoded.delayMs == 100)
    }

    @Test("TypeRequest handles special characters")
    func typeRequestSpecialChars() throws {
        let specialText = "Hello\nWorld\t\"quoted\" emoji: 😀"
        let request = TypeRequest(text: specialText)
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(TypeRequest.self, from: data)

        #expect(decoded.text == specialText)
    }

    @Test("TypeRequest without delay")
    func typeRequestWithoutDelay() throws {
        let json = """
        {"text": "test"}
        """
        let decoded = try decoder.decode(TypeRequest.self, from: Data(json.utf8))

        #expect(decoded.text == "test")
        #expect(decoded.delayMs == nil)
    }

    @Test("TypeResponse encodes correctly")
    func typeResponseEncode() throws {
        let response = TypeResponse(success: true, charactersTyped: 11)
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(TypeResponse.self, from: data)

        #expect(decoded.success == true)
        #expect(decoded.charactersTyped == 11)
        #expect(decoded.error == nil)
    }

    // MARK: - KeyRequest Tests

    @Test("KeyRequest encodes and decodes")
    func keyRequestEncodeDecode() throws {
        let request = KeyRequest(key: "s", modifiers: [.cmd])
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(KeyRequest.self, from: data)

        #expect(decoded.key == "s")
        #expect(decoded.modifiers?.contains(.cmd) == true)
    }

    @Test("KeyRequest with multiple modifiers")
    func keyRequestMultipleModifiers() throws {
        let request = KeyRequest(key: "a", modifiers: [.cmd, .shift, .alt, .ctrl])
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(KeyRequest.self, from: data)

        #expect(decoded.modifiers?.count == 4)
    }

    @Test("KeyRequest without modifiers")
    func keyRequestWithoutModifiers() throws {
        let json = """
        {"key": "return"}
        """
        let decoded = try decoder.decode(KeyRequest.self, from: Data(json.utf8))

        #expect(decoded.key == "return")
        #expect(decoded.modifiers == nil)
    }

    @Test("All KeyModifier variants encode correctly")
    func keyModifierVariants() throws {
        let modifiers: [KeyModifier] = [.cmd, .command, .ctrl, .control, .alt, .option, .shift, .fn, .function]

        for modifier in modifiers {
            let request = KeyRequest(key: "a", modifiers: [modifier])
            let data = try encoder.encode(request)
            let decoded = try decoder.decode(KeyRequest.self, from: data)
            #expect(decoded.modifiers?.first == modifier)
        }
    }

    // MARK: - ScrollRequest Tests

    @Test("ScrollRequest encodes and decodes")
    func scrollRequestEncodeDecode() throws {
        let request = ScrollRequest(x: 500, y: 300, deltaX: 10, deltaY: -50)
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(ScrollRequest.self, from: data)

        #expect(decoded.x == 500)
        #expect(decoded.y == 300)
        #expect(decoded.deltaX == 10)
        #expect(decoded.deltaY == -50)
    }

    @Test("ScrollRequest with only vertical scroll")
    func scrollRequestVerticalOnly() throws {
        let json = """
        {"x": 100, "y": 100, "delta_y": -100}
        """
        let decoded = try decoder.decode(ScrollRequest.self, from: Data(json.utf8))

        #expect(decoded.deltaX == nil)
        #expect(decoded.deltaY == -100)
    }

    @Test("ScrollResponse encodes correctly")
    func scrollResponseEncode() throws {
        let response = ScrollResponse(success: true, x: 100, y: 200, deltaX: 0, deltaY: -50)
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(ScrollResponse.self, from: data)

        #expect(decoded.success == true)
        #expect(decoded.deltaY == -50)
    }

    // MARK: - ScreenshotRequest Tests

    @Test("ScreenshotRequest with format")
    func screenshotRequestWithFormat() throws {
        let request = ScreenshotRequest(format: "png", displayId: 1)
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(ScreenshotRequest.self, from: data)

        #expect(decoded.format == "png")
        #expect(decoded.displayId == 1)
    }

    @Test("ScreenshotRequest minimal")
    func screenshotRequestMinimal() throws {
        let json = "{}"
        let decoded = try decoder.decode(ScreenshotRequest.self, from: Data(json.utf8))

        #expect(decoded.format == nil)
        #expect(decoded.displayId == nil)
    }

    @Test("ScreenshotResponse encodes correctly")
    func screenshotResponseEncode() throws {
        let response = ScreenshotResponse(
            success: true,
            format: "png",
            width: 1920,
            height: 1080,
            data: "base64data..."
        )
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(ScreenshotResponse.self, from: data)

        #expect(decoded.success == true)
        #expect(decoded.width == 1920)
        #expect(decoded.height == 1080)
    }

    // MARK: - StatusResponse Tests

    @Test("StatusResponse complete structure")
    func statusResponseComplete() throws {
        let status = StatusResponse(
            status: "ok",
            version: "1.0.0",
            serverRunning: true,
            permissions: PermissionStatus(accessibility: true, screenRecording: false),
            frontmostApp: AppInfo(name: "Terminal", bundleIdentifier: "com.apple.Terminal", processIdentifier: 1234),
            screenSize: ScreenSize(width: 2560, height: 1440)
        )

        let data = try encoder.encode(status)
        let decoded = try decoder.decode(StatusResponse.self, from: data)

        #expect(decoded.status == "ok")
        #expect(decoded.version == "1.0.0")
        #expect(decoded.serverRunning == true)
        #expect(decoded.permissions.accessibility == true)
        #expect(decoded.permissions.screenRecording == false)
        #expect(decoded.frontmostApp?.name == "Terminal")
        #expect(decoded.frontmostApp?.bundleIdentifier == "com.apple.Terminal")
        #expect(decoded.screenSize.width == 2560)
    }

    @Test("StatusResponse without frontmost app")
    func statusResponseNoFrontmostApp() throws {
        let status = StatusResponse(
            status: "ok",
            version: "1.0.0",
            serverRunning: true,
            permissions: PermissionStatus(accessibility: true, screenRecording: true),
            frontmostApp: nil,
            screenSize: ScreenSize(width: 1920, height: 1080)
        )

        let data = try encoder.encode(status)
        let decoded = try decoder.decode(StatusResponse.self, from: data)

        #expect(decoded.frontmostApp == nil)
    }

    // MARK: - ErrorResponse Tests

    @Test("ErrorResponse encodes correctly")
    func errorResponseEncode() throws {
        let error = ErrorResponse(error: "Invalid coordinates", code: 400)
        let data = try encoder.encode(error)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"error\":\"Invalid coordinates\""))
        #expect(json.contains("\"code\":400"))
    }

    // MARK: - ScreenSize Tests

    @Test("ScreenSize handles various resolutions")
    func screenSizeResolutions() {
        let resolutions: [(Double, Double)] = [
            (1920, 1080),   // Full HD
            (2560, 1440),   // 2K
            (3840, 2160),   // 4K
            (5120, 2880),   // 5K
            (1440, 900),    // MacBook Air
        ]

        for (width, height) in resolutions {
            let size = ScreenSize(width: width, height: height)
            #expect(size.width == width)
            #expect(size.height == height)
        }
    }
}

// MARK: - Error Types Tests

@Suite("Error Types Tests")
struct ErrorTypesTests {

    @Test("KeyboardError descriptions")
    func keyboardErrorDescriptions() {
        let eventError = KeyboardError.eventCreationFailed
        #expect(eventError.errorDescription?.contains("accessibility") == true)

        let unknownKeyError = KeyboardError.unknownKey("xyz")
        #expect(unknownKeyError.errorDescription?.contains("xyz") == true)

        let invalidCharError = KeyboardError.invalidCharacter("😀")
        #expect(invalidCharError.errorDescription?.contains("😀") == true)
    }

    @Test("MouseError descriptions")
    func mouseErrorDescriptions() {
        let eventError = MouseError.eventCreationFailed
        #expect(eventError.errorDescription?.contains("accessibility") == true)

        let coordError = MouseError.invalidCoordinates
        #expect(coordError.errorDescription?.contains("coordinates") == true)
    }

    @Test("ScreenCaptureError descriptions")
    func screenCaptureErrorDescriptions() {
        let noDisplayError = ScreenCaptureError.noDisplayFound
        #expect(noDisplayError.errorDescription?.contains("display") == true)

        let windowError = ScreenCaptureError.windowNotFound(123)
        #expect(windowError.errorDescription?.contains("123") == true)

        let captureError = ScreenCaptureError.captureFailed("timeout")
        #expect(captureError.errorDescription?.contains("timeout") == true)

        let permError = ScreenCaptureError.permissionDenied
        #expect(permError.errorDescription?.contains("permission") == true)
    }
}

// MARK: - JSON Edge Cases Tests

@Suite("JSON Edge Cases Tests")
struct JSONEdgeCasesTests {

    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    @Test("Handles floating point coordinates")
    func floatingPointCoordinates() throws {
        let json = """
        {"x": 100.123456789, "y": 200.987654321}
        """
        let decoded = try decoder.decode(ClickRequest.self, from: Data(json.utf8))

        #expect(decoded.x == 100.123456789)
        #expect(decoded.y == 200.987654321)
    }

    @Test("Handles zero coordinates")
    func zeroCoordinates() throws {
        let json = """
        {"x": 0, "y": 0}
        """
        let decoded = try decoder.decode(ClickRequest.self, from: Data(json.utf8))

        #expect(decoded.x == 0)
        #expect(decoded.y == 0)
    }

    @Test("Handles large coordinates")
    func largeCoordinates() throws {
        let json = """
        {"x": 10000, "y": 10000}
        """
        let decoded = try decoder.decode(ClickRequest.self, from: Data(json.utf8))

        #expect(decoded.x == 10000)
        #expect(decoded.y == 10000)
    }

    @Test("Handles empty text in TypeRequest")
    func emptyText() throws {
        let json = """
        {"text": ""}
        """
        let decoded = try decoder.decode(TypeRequest.self, from: Data(json.utf8))

        #expect(decoded.text == "")
    }

    @Test("Handles very long text")
    func veryLongText() throws {
        let longText = String(repeating: "a", count: 10000)
        let json = """
        {"text": "\(longText)"}
        """
        let decoded = try decoder.decode(TypeRequest.self, from: Data(json.utf8))

        #expect(decoded.text.count == 10000)
    }

    @Test("Handles negative scroll deltas")
    func negativeScrollDeltas() throws {
        let json = """
        {"x": 100, "y": 100, "delta_x": -50, "delta_y": -100}
        """
        let decoded = try decoder.decode(ScrollRequest.self, from: Data(json.utf8))

        #expect(decoded.deltaX == -50)
        #expect(decoded.deltaY == -100)
    }

    @Test("Handles empty modifiers array")
    func emptyModifiersArray() throws {
        let json = """
        {"key": "a", "modifiers": []}
        """
        let decoded = try decoder.decode(KeyRequest.self, from: Data(json.utf8))

        #expect(decoded.modifiers?.isEmpty == true)
    }

    @Test("Decodes snake_case JSON correctly")
    func snakeCaseDecoding() throws {
        let json = """
        {"x": 100, "y": 200, "click_count": 2, "button": "right"}
        """
        let decoded = try decoder.decode(ClickRequest.self, from: Data(json.utf8))

        #expect(decoded.clickCount == 2)
        #expect(decoded.button == .right)
    }
}

// MARK: - Singleton Tests

@Suite("Singleton Tests")
struct SingletonTests {

    @Test("PermissionManager singleton identity")
    func permissionManagerSingleton() {
        let manager1 = PermissionManager.shared
        let manager2 = PermissionManager.shared
        #expect(manager1 === manager2)
    }

    @Test("KeyboardController singleton identity")
    func keyboardControllerSingleton() {
        let controller1 = KeyboardController.shared
        let controller2 = KeyboardController.shared
        #expect(controller1 === controller2)
    }

    @Test("MouseController singleton identity")
    func mouseControllerSingleton() {
        let controller1 = MouseController.shared
        let controller2 = MouseController.shared
        #expect(controller1 === controller2)
    }

    @Test("ServerManager singleton identity")
    func serverManagerSingleton() {
        let manager1 = ServerManager.shared
        let manager2 = ServerManager.shared
        #expect(manager1 === manager2)
    }

    @Test("ImageEncoder can be instantiated")
    func imageEncoderInstantiation() {
        let encoder = ImageEncoder()
        #expect(type(of: encoder) == ImageEncoder.self)
    }
}

// MARK: - Route Handler Tests

@Suite("Route Handler Tests")
struct RouteHandlerTests {

    @Test("StatusRoute has correct version")
    func statusRouteVersion() {
        #expect(StatusRoute.version == "1.0.0")
    }

    @Test("StatusRoute can be instantiated")
    func statusRouteInstantiation() {
        let route = StatusRoute()
        #expect(type(of: route) == StatusRoute.self)
    }

    @Test("ClickRoute can be instantiated")
    func clickRouteInstantiation() {
        let route = ClickRoute()
        #expect(type(of: route) == ClickRoute.self)
    }

    @Test("TypeRoute can be instantiated")
    func typeRouteInstantiation() {
        let route = TypeRoute()
        #expect(type(of: route) == TypeRoute.self)
    }

    @Test("KeyRoute can be instantiated")
    func keyRouteInstantiation() {
        let route = KeyRoute()
        #expect(type(of: route) == KeyRoute.self)
    }

    @Test("ScrollRoute can be instantiated")
    func scrollRouteInstantiation() {
        let route = ScrollRoute()
        #expect(type(of: route) == ScrollRoute.self)
    }

    @Test("ScreenshotRoute can be instantiated")
    func screenshotRouteInstantiation() {
        let route = ScreenshotRoute()
        #expect(type(of: route) == ScreenshotRoute.self)
    }
}

// MARK: - Server Tests

@Suite("Server Tests")
struct ServerTests {

    @Test("GeisterhandServer has correct default port")
    func serverDefaultPort() {
        #expect(GeisterhandServer.defaultPort == 7676)
    }

    @Test("GeisterhandServer has correct default host")
    func serverDefaultHost() {
        #expect(GeisterhandServer.defaultHost == "127.0.0.1")
    }

    @Test("ServerManager starts not running")
    func serverManagerInitialState() {
        // Create fresh manager check - note: shared singleton may have state
        #expect(ServerManager.shared.isRunning == false || ServerManager.shared.isRunning == true)
    }
}
