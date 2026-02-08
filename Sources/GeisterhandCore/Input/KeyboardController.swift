import Foundation
import CoreGraphics
import Carbon.HIToolbox
import CAXKeyboardEvent

/// Controls keyboard input using CGEvent
public final class KeyboardController: Sendable {
    public static let shared = KeyboardController()

    private init() {}

    /// Types a string of text
    /// - Parameters:
    ///   - text: The text to type
    ///   - delayMs: Delay between keystrokes in milliseconds
    ///   - targetPid: Optional target process ID for PID-targeted events
    /// - Throws: KeyboardError if typing fails
    /// - Returns: Number of characters successfully typed
    @discardableResult
    public func type(text: String, delayMs: Int = 0, targetPid: Int32? = nil) throws -> Int {
        var typedCount = 0

        for character in text {
            try typeCharacter(character, targetPid: targetPid)
            typedCount += 1

            if delayMs > 0 {
                Thread.sleep(forTimeInterval: Double(delayMs) / 1000.0)
            }
        }

        return typedCount
    }

    /// Types a single character
    /// - Parameters:
    ///   - character: The character to type
    ///   - targetPid: Optional target process ID for PID-targeted events
    /// - Throws: KeyboardError if typing fails
    public func typeCharacter(_ character: Character, targetPid: Int32? = nil) throws {
        // Always use Unicode input for consistent behavior across keyboard layouts
        try typeUnicodeCharacter(character, targetPid: targetPid)
    }

    /// Presses a key by name with optional modifiers
    /// - Parameters:
    ///   - key: The key name (e.g., "a", "return", "f1")
    ///   - modifiers: Key modifiers to hold
    /// - Throws: KeyboardError if the key press fails
    public func pressKey(key: String, modifiers: [KeyModifier] = []) throws {
        guard let keyCode = KeyCodeMap.keyCode(for: key) else {
            throw KeyboardError.unknownKey(key)
        }

        try pressKey(keyCode: keyCode, modifiers: modifiers)
    }

    /// Presses a key by key code with optional modifiers
    /// - Parameters:
    ///   - keyCode: The CGKeyCode to press
    ///   - modifiers: Key modifiers to hold
    /// - Throws: KeyboardError if the key press fails
    public func pressKey(keyCode: UInt16, modifiers: [KeyModifier] = []) throws {
        let modifierFlags = self.modifierFlags(for: modifiers)

        // Press modifiers down
        for modifier in modifiers {
            try pressModifierDown(modifier)
        }

        // Key down
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw KeyboardError.eventCreationFailed
        }
        if !modifiers.isEmpty {
            keyDown.flags = modifierFlags
        }
        keyDown.post(tap: .cghidEventTap)

        // Key up
        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw KeyboardError.eventCreationFailed
        }
        if !modifiers.isEmpty {
            keyUp.flags = modifierFlags
        }
        keyUp.post(tap: .cghidEventTap)

        // Release modifiers
        for modifier in modifiers.reversed() {
            try releaseModifier(modifier)
        }
    }

    /// Presses a key by name with optional modifiers, targeted at a specific process
    /// - Parameters:
    ///   - key: The key name (e.g., "a", "return", "f1")
    ///   - modifiers: Key modifiers to hold
    ///   - targetPid: The PID of the target process
    /// - Throws: KeyboardError if the key press fails
    public func pressKey(key: String, modifiers: [KeyModifier] = [], targetPid: Int32) throws {
        guard let keyCode = KeyCodeMap.keyCode(for: key) else {
            throw KeyboardError.unknownKey(key)
        }

        let appElement = AXUIElementCreateApplication(pid_t(targetPid))

        // Press modifiers down
        for modifier in modifiers {
            try pressModifierDown(modifier, targetPid: targetPid)
        }

        // Key down
        let downResult = CAXPostKeyboardEvent(appElement, 0, CGKeyCode(keyCode), true)
        guard downResult == .success else {
            throw KeyboardError.eventCreationFailed
        }

        // Key up
        let upResult = CAXPostKeyboardEvent(appElement, 0, CGKeyCode(keyCode), false)
        guard upResult == .success else {
            throw KeyboardError.eventCreationFailed
        }

        // Release modifiers
        for modifier in modifiers.reversed() {
            try releaseModifier(modifier, targetPid: targetPid)
        }
    }

    /// Holds a key down without releasing
    /// - Parameters:
    ///   - key: The key name
    ///   - modifiers: Key modifiers to hold
    /// - Throws: KeyboardError if the key press fails
    public func keyDown(key: String, modifiers: [KeyModifier] = []) throws {
        guard let keyCode = KeyCodeMap.keyCode(for: key) else {
            throw KeyboardError.unknownKey(key)
        }

        let modifierFlags = self.modifierFlags(for: modifiers)

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw KeyboardError.eventCreationFailed
        }
        if !modifiers.isEmpty {
            keyDown.flags = modifierFlags
        }
        keyDown.post(tap: .cghidEventTap)
    }

    /// Releases a held key
    /// - Parameters:
    ///   - key: The key name
    ///   - modifiers: Key modifiers that were held
    /// - Throws: KeyboardError if the key release fails
    public func keyUp(key: String, modifiers: [KeyModifier] = []) throws {
        guard let keyCode = KeyCodeMap.keyCode(for: key) else {
            throw KeyboardError.unknownKey(key)
        }

        let modifierFlags = self.modifierFlags(for: modifiers)

        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw KeyboardError.eventCreationFailed
        }
        if !modifiers.isEmpty {
            keyUp.flags = modifierFlags
        }
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: - Private Helpers

    private func typeUnicodeCharacter(_ character: Character, targetPid: Int32? = nil) throws {
        // For PID-targeted typing, prefer CAXPostKeyboardEvent when possible
        if let pid = targetPid, let mapping = KeyCodeMap.keyCodeForCharacter(character) {
            let appElement = AXUIElementCreateApplication(pid_t(pid))

            // Press shift if needed
            if mapping.needsShift {
                CAXPostKeyboardEvent(appElement, 0, CGKeyCode(kVK_Shift), true)
            }

            // Key down + up
            CAXPostKeyboardEvent(appElement, 0, CGKeyCode(mapping.keyCode), true)
            CAXPostKeyboardEvent(appElement, 0, CGKeyCode(mapping.keyCode), false)

            // Release shift if needed
            if mapping.needsShift {
                CAXPostKeyboardEvent(appElement, 0, CGKeyCode(kVK_Shift), false)
            }
            return
        }

        // For non-PID or characters without key code mappings, use CGEvent unicode path
        let string = String(character)
        guard let unicodeScalar = string.unicodeScalars.first else {
            throw KeyboardError.invalidCharacter(character)
        }

        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            throw KeyboardError.eventCreationFailed
        }

        var unichar = UniChar(unicodeScalar.value)
        event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unichar)

        if let pid = targetPid {
            // Fallback for unicode chars without key codes — best effort
            event.postToPid(pid)
        } else {
            event.post(tap: .cghidEventTap)
        }

        // Key up
        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            throw KeyboardError.eventCreationFailed
        }
        keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unichar)

        if let pid = targetPid {
            keyUp.postToPid(pid)
        } else {
            keyUp.post(tap: .cghidEventTap)
        }
    }

    private func pressModifierDown(_ modifier: KeyModifier) throws {
        let keyCode = modifierKeyCode(for: modifier)

        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw KeyboardError.eventCreationFailed
        }
        event.flags = singleModifierFlag(for: modifier)
        event.post(tap: .cghidEventTap)
    }

    private func releaseModifier(_ modifier: KeyModifier) throws {
        let keyCode = modifierKeyCode(for: modifier)

        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw KeyboardError.eventCreationFailed
        }
        event.post(tap: .cghidEventTap)
    }

    private func pressModifierDown(_ modifier: KeyModifier, targetPid: Int32) throws {
        let keyCode = modifierKeyCode(for: modifier)
        let appElement = AXUIElementCreateApplication(pid_t(targetPid))

        let result = CAXPostKeyboardEvent(appElement, 0, CGKeyCode(keyCode), true)
        guard result == .success else {
            throw KeyboardError.eventCreationFailed
        }
    }

    private func releaseModifier(_ modifier: KeyModifier, targetPid: Int32) throws {
        let keyCode = modifierKeyCode(for: modifier)
        let appElement = AXUIElementCreateApplication(pid_t(targetPid))

        let result = CAXPostKeyboardEvent(appElement, 0, CGKeyCode(keyCode), false)
        guard result == .success else {
            throw KeyboardError.eventCreationFailed
        }
    }

    private func modifierKeyCode(for modifier: KeyModifier) -> UInt16 {
        switch modifier {
        case .cmd, .command:
            return UInt16(kVK_Command)
        case .ctrl, .control:
            return UInt16(kVK_Control)
        case .alt, .option:
            return UInt16(kVK_Option)
        case .shift:
            return UInt16(kVK_Shift)
        case .fn, .function:
            return UInt16(kVK_Function)
        }
    }

    private func modifierFlags(for modifiers: [KeyModifier]) -> CGEventFlags {
        var flags: CGEventFlags = []

        for modifier in modifiers {
            flags.insert(singleModifierFlag(for: modifier))
        }

        return flags
    }

    private func singleModifierFlag(for modifier: KeyModifier) -> CGEventFlags {
        switch modifier {
        case .cmd, .command:
            return .maskCommand
        case .ctrl, .control:
            return .maskControl
        case .alt, .option:
            return .maskAlternate
        case .shift:
            return .maskShift
        case .fn, .function:
            return .maskSecondaryFn
        }
    }
}

// MARK: - Error Types

public enum KeyboardError: Error, LocalizedError {
    case eventCreationFailed
    case unknownKey(String)
    case invalidCharacter(Character)

    public var errorDescription: String? {
        switch self {
        case .eventCreationFailed:
            return "Failed to create keyboard event. Check accessibility permissions."
        case .unknownKey(let key):
            return "Unknown key: \(key)"
        case .invalidCharacter(let char):
            return "Invalid character: \(char)"
        }
    }
}
