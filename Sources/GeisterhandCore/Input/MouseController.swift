import Foundation
import CoreGraphics
import AppKit

/// Controls mouse input using CGEvent
public final class MouseController: Sendable {
    public static let shared = MouseController()

    private init() {}

    /// Performs a mouse click at the specified coordinates
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - button: Mouse button to click
    ///   - clickCount: Number of clicks (1 for single, 2 for double, etc.)
    ///   - modifiers: Key modifiers to hold during click
    /// - Throws: MouseError if the click fails
    public func click(
        x: Double,
        y: Double,
        button: MouseButton = .left,
        clickCount: Int = 1,
        modifiers: [KeyModifier] = []
    ) throws {
        let point = CGPoint(x: x, y: y)
        let (downType, upType) = eventTypes(for: button)
        let cgButton = cgMouseButton(for: button)
        let modifierFlags = modifierFlags(for: modifiers)

        // Create mouse down event
        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: downType,
            mouseCursorPosition: point,
            mouseButton: cgButton
        ) else {
            throw MouseError.eventCreationFailed
        }

        // Create mouse up event
        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: upType,
            mouseCursorPosition: point,
            mouseButton: cgButton
        ) else {
            throw MouseError.eventCreationFailed
        }

        // Set click count for double/triple clicks
        mouseDown.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        mouseUp.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))

        // Apply modifiers if any
        if !modifiers.isEmpty {
            mouseDown.flags = modifierFlags
            mouseUp.flags = modifierFlags
        }

        // Perform the click(s)
        for i in 0..<clickCount {
            if i > 0 {
                // Small delay between multiple clicks
                Thread.sleep(forTimeInterval: 0.05)
            }
            mouseDown.post(tap: .cghidEventTap)
            mouseUp.post(tap: .cghidEventTap)
        }
    }

    /// Moves the mouse to the specified coordinates
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    /// - Throws: MouseError if the move fails
    public func move(x: Double, y: Double) throws {
        let point = CGPoint(x: x, y: y)

        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            throw MouseError.eventCreationFailed
        }

        event.post(tap: .cghidEventTap)
    }

    /// Performs a drag operation from one point to another
    /// - Parameters:
    ///   - fromX: Starting X coordinate
    ///   - fromY: Starting Y coordinate
    ///   - toX: Ending X coordinate
    ///   - toY: Ending Y coordinate
    ///   - button: Mouse button to use for dragging
    /// - Throws: MouseError if the drag fails
    public func drag(
        fromX: Double,
        fromY: Double,
        toX: Double,
        toY: Double,
        button: MouseButton = .left
    ) throws {
        let startPoint = CGPoint(x: fromX, y: fromY)
        let endPoint = CGPoint(x: toX, y: toY)
        let (downType, upType) = eventTypes(for: button)
        let cgButton = cgMouseButton(for: button)
        let dragType = dragEventType(for: button)

        // Mouse down at start
        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: downType,
            mouseCursorPosition: startPoint,
            mouseButton: cgButton
        ) else {
            throw MouseError.eventCreationFailed
        }
        mouseDown.post(tap: .cghidEventTap)

        // Drag to end position
        guard let mouseDrag = CGEvent(
            mouseEventSource: nil,
            mouseType: dragType,
            mouseCursorPosition: endPoint,
            mouseButton: cgButton
        ) else {
            throw MouseError.eventCreationFailed
        }
        mouseDrag.post(tap: .cghidEventTap)

        // Mouse up at end
        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: upType,
            mouseCursorPosition: endPoint,
            mouseButton: cgButton
        ) else {
            throw MouseError.eventCreationFailed
        }
        mouseUp.post(tap: .cghidEventTap)
    }

    /// Scrolls at the specified position
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - deltaX: Horizontal scroll amount (positive = right)
    ///   - deltaY: Vertical scroll amount (positive = down, negative = up)
    /// - Throws: MouseError if the scroll fails
    public func scroll(x: Double, y: Double, deltaX: Double = 0, deltaY: Double = 0) throws {
        // First move mouse to position
        try move(x: x, y: y)

        // Create scroll event
        guard let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(deltaY),
            wheel2: Int32(deltaX),
            wheel3: 0
        ) else {
            throw MouseError.eventCreationFailed
        }

        scrollEvent.post(tap: .cghidEventTap)
    }

    /// Gets the current mouse position
    public var currentPosition: CGPoint {
        NSEvent.mouseLocation
    }

    // MARK: - Private Helpers

    private func eventTypes(for button: MouseButton) -> (down: CGEventType, up: CGEventType) {
        switch button {
        case .left:
            return (.leftMouseDown, .leftMouseUp)
        case .right:
            return (.rightMouseDown, .rightMouseUp)
        case .center:
            return (.otherMouseDown, .otherMouseUp)
        }
    }

    private func dragEventType(for button: MouseButton) -> CGEventType {
        switch button {
        case .left:
            return .leftMouseDragged
        case .right:
            return .rightMouseDragged
        case .center:
            return .otherMouseDragged
        }
    }

    private func cgMouseButton(for button: MouseButton) -> CGMouseButton {
        switch button {
        case .left:
            return .left
        case .right:
            return .right
        case .center:
            return .center
        }
    }

    private func modifierFlags(for modifiers: [KeyModifier]) -> CGEventFlags {
        var flags: CGEventFlags = []

        for modifier in modifiers {
            switch modifier {
            case .cmd, .command:
                flags.insert(.maskCommand)
            case .ctrl, .control:
                flags.insert(.maskControl)
            case .alt, .option:
                flags.insert(.maskAlternate)
            case .shift:
                flags.insert(.maskShift)
            case .fn, .function:
                flags.insert(.maskSecondaryFn)
            }
        }

        return flags
    }
}

// MARK: - Error Types

public enum MouseError: Error, LocalizedError {
    case eventCreationFailed
    case invalidCoordinates

    public var errorDescription: String? {
        switch self {
        case .eventCreationFailed:
            return "Failed to create mouse event. Check accessibility permissions."
        case .invalidCoordinates:
            return "Invalid mouse coordinates provided."
        }
    }
}
