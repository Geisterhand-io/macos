import Foundation
import Carbon.HIToolbox

/// Maps key names to their CGKeyCode values
public struct KeyCodeMap: Sendable {
    /// Standard US keyboard key codes
    public static let keyCodes: [String: UInt16] = [
        // Letters
        "a": UInt16(kVK_ANSI_A),
        "b": UInt16(kVK_ANSI_B),
        "c": UInt16(kVK_ANSI_C),
        "d": UInt16(kVK_ANSI_D),
        "e": UInt16(kVK_ANSI_E),
        "f": UInt16(kVK_ANSI_F),
        "g": UInt16(kVK_ANSI_G),
        "h": UInt16(kVK_ANSI_H),
        "i": UInt16(kVK_ANSI_I),
        "j": UInt16(kVK_ANSI_J),
        "k": UInt16(kVK_ANSI_K),
        "l": UInt16(kVK_ANSI_L),
        "m": UInt16(kVK_ANSI_M),
        "n": UInt16(kVK_ANSI_N),
        "o": UInt16(kVK_ANSI_O),
        "p": UInt16(kVK_ANSI_P),
        "q": UInt16(kVK_ANSI_Q),
        "r": UInt16(kVK_ANSI_R),
        "s": UInt16(kVK_ANSI_S),
        "t": UInt16(kVK_ANSI_T),
        "u": UInt16(kVK_ANSI_U),
        "v": UInt16(kVK_ANSI_V),
        "w": UInt16(kVK_ANSI_W),
        "x": UInt16(kVK_ANSI_X),
        "y": UInt16(kVK_ANSI_Y),
        "z": UInt16(kVK_ANSI_Z),

        // Numbers
        "0": UInt16(kVK_ANSI_0),
        "1": UInt16(kVK_ANSI_1),
        "2": UInt16(kVK_ANSI_2),
        "3": UInt16(kVK_ANSI_3),
        "4": UInt16(kVK_ANSI_4),
        "5": UInt16(kVK_ANSI_5),
        "6": UInt16(kVK_ANSI_6),
        "7": UInt16(kVK_ANSI_7),
        "8": UInt16(kVK_ANSI_8),
        "9": UInt16(kVK_ANSI_9),

        // Function keys
        "f1": UInt16(kVK_F1),
        "f2": UInt16(kVK_F2),
        "f3": UInt16(kVK_F3),
        "f4": UInt16(kVK_F4),
        "f5": UInt16(kVK_F5),
        "f6": UInt16(kVK_F6),
        "f7": UInt16(kVK_F7),
        "f8": UInt16(kVK_F8),
        "f9": UInt16(kVK_F9),
        "f10": UInt16(kVK_F10),
        "f11": UInt16(kVK_F11),
        "f12": UInt16(kVK_F12),
        "f13": UInt16(kVK_F13),
        "f14": UInt16(kVK_F14),
        "f15": UInt16(kVK_F15),
        "f16": UInt16(kVK_F16),
        "f17": UInt16(kVK_F17),
        "f18": UInt16(kVK_F18),
        "f19": UInt16(kVK_F19),
        "f20": UInt16(kVK_F20),

        // Special keys
        "return": UInt16(kVK_Return),
        "enter": UInt16(kVK_Return),
        "tab": UInt16(kVK_Tab),
        "space": UInt16(kVK_Space),
        "delete": UInt16(kVK_Delete),
        "backspace": UInt16(kVK_Delete),
        "forwarddelete": UInt16(kVK_ForwardDelete),
        "escape": UInt16(kVK_Escape),
        "esc": UInt16(kVK_Escape),

        // Arrow keys
        "left": UInt16(kVK_LeftArrow),
        "leftarrow": UInt16(kVK_LeftArrow),
        "right": UInt16(kVK_RightArrow),
        "rightarrow": UInt16(kVK_RightArrow),
        "up": UInt16(kVK_UpArrow),
        "uparrow": UInt16(kVK_UpArrow),
        "down": UInt16(kVK_DownArrow),
        "downarrow": UInt16(kVK_DownArrow),

        // Navigation keys
        "home": UInt16(kVK_Home),
        "end": UInt16(kVK_End),
        "pageup": UInt16(kVK_PageUp),
        "pagedown": UInt16(kVK_PageDown),

        // Modifier keys (for standalone presses)
        "command": UInt16(kVK_Command),
        "cmd": UInt16(kVK_Command),
        "shift": UInt16(kVK_Shift),
        "option": UInt16(kVK_Option),
        "alt": UInt16(kVK_Option),
        "control": UInt16(kVK_Control),
        "ctrl": UInt16(kVK_Control),
        "capslock": UInt16(kVK_CapsLock),
        "fn": UInt16(kVK_Function),
        "function": UInt16(kVK_Function),

        // Punctuation and symbols
        "minus": UInt16(kVK_ANSI_Minus),
        "-": UInt16(kVK_ANSI_Minus),
        "equal": UInt16(kVK_ANSI_Equal),
        "=": UInt16(kVK_ANSI_Equal),
        "leftbracket": UInt16(kVK_ANSI_LeftBracket),
        "[": UInt16(kVK_ANSI_LeftBracket),
        "rightbracket": UInt16(kVK_ANSI_RightBracket),
        "]": UInt16(kVK_ANSI_RightBracket),
        "semicolon": UInt16(kVK_ANSI_Semicolon),
        ";": UInt16(kVK_ANSI_Semicolon),
        "quote": UInt16(kVK_ANSI_Quote),
        "'": UInt16(kVK_ANSI_Quote),
        "backslash": UInt16(kVK_ANSI_Backslash),
        "\\": UInt16(kVK_ANSI_Backslash),
        "comma": UInt16(kVK_ANSI_Comma),
        ",": UInt16(kVK_ANSI_Comma),
        "period": UInt16(kVK_ANSI_Period),
        ".": UInt16(kVK_ANSI_Period),
        "slash": UInt16(kVK_ANSI_Slash),
        "/": UInt16(kVK_ANSI_Slash),
        "grave": UInt16(kVK_ANSI_Grave),
        "`": UInt16(kVK_ANSI_Grave),

        // Keypad
        "keypad0": UInt16(kVK_ANSI_Keypad0),
        "keypad1": UInt16(kVK_ANSI_Keypad1),
        "keypad2": UInt16(kVK_ANSI_Keypad2),
        "keypad3": UInt16(kVK_ANSI_Keypad3),
        "keypad4": UInt16(kVK_ANSI_Keypad4),
        "keypad5": UInt16(kVK_ANSI_Keypad5),
        "keypad6": UInt16(kVK_ANSI_Keypad6),
        "keypad7": UInt16(kVK_ANSI_Keypad7),
        "keypad8": UInt16(kVK_ANSI_Keypad8),
        "keypad9": UInt16(kVK_ANSI_Keypad9),
        "keypadclear": UInt16(kVK_ANSI_KeypadClear),
        "keypadenter": UInt16(kVK_ANSI_KeypadEnter),
        "keypaddecimal": UInt16(kVK_ANSI_KeypadDecimal),
        "keypadplus": UInt16(kVK_ANSI_KeypadPlus),
        "keypadminus": UInt16(kVK_ANSI_KeypadMinus),
        "keypadmultiply": UInt16(kVK_ANSI_KeypadMultiply),
        "keypaddivide": UInt16(kVK_ANSI_KeypadDivide),
        "keypadequals": UInt16(kVK_ANSI_KeypadEquals),

        // Media keys
        "volumeup": UInt16(kVK_VolumeUp),
        "volumedown": UInt16(kVK_VolumeDown),
        "mute": UInt16(kVK_Mute),
    ]

    /// Gets the key code for a given key name
    /// - Parameter key: The key name (case-insensitive)
    /// - Returns: The CGKeyCode if found
    public static func keyCode(for key: String) -> UInt16? {
        keyCodes[key.lowercased()]
    }

    /// Converts a character to its key code and required modifiers
    /// - Parameter character: A single character
    /// - Returns: A tuple of (keyCode, needsShift) or nil if not found
    public static func keyCodeForCharacter(_ character: Character) -> (keyCode: UInt16, needsShift: Bool)? {
        let lower = character.lowercased()

        // Check if it's a basic key
        if let keyCode = keyCodes[lower] {
            let needsShift = character.isUppercase || shiftCharacters.contains(character)
            return (keyCode, needsShift)
        }

        // Check shift character mapping
        if let baseChar = shiftCharacterMap[character] {
            if let keyCode = keyCodes[String(baseChar)] {
                return (keyCode, true)
            }
        }

        return nil
    }

    /// Characters that require shift to type
    private static let shiftCharacters: Set<Character> = [
        "!", "@", "#", "$", "%", "^", "&", "*", "(", ")",
        "_", "+", "{", "}", "|", ":", "\"", "<", ">", "?", "~"
    ]

    /// Maps shift characters to their base key
    private static let shiftCharacterMap: [Character: Character] = [
        "!": "1", "@": "2", "#": "3", "$": "4", "%": "5",
        "^": "6", "&": "7", "*": "8", "(": "9", ")": "0",
        "_": "-", "+": "=", "{": "[", "}": "]", "|": "\\",
        ":": ";", "\"": "'", "<": ",", ">": ".", "?": "/", "~": "`"
    ]
}
