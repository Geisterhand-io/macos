import Foundation

// MARK: - Element Path

/// Identifies an element by its process ID and path from the app root
public struct ElementPath: Codable, Sendable, Hashable {
    /// The process identifier of the application
    public let pid: Int32
    /// Array of child indices from the app root element
    public let path: [Int]

    public init(pid: Int32, path: [Int]) {
        self.pid = pid
        self.path = path
    }
}

// MARK: - Element Frame

/// Rectangle representing an element's position and size
public struct ElementFrame: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Center point of the frame
    public var center: (x: Double, y: Double) {
        (x + width / 2, y + height / 2)
    }
}

// MARK: - UI Element Info

/// Information about a UI element
public struct UIElementInfo: Codable, Sendable {
    /// Path to locate this element
    public let path: ElementPath
    /// Accessibility role (e.g., "AXButton", "AXTextField")
    public let role: String
    /// The element's title attribute
    public let title: String?
    /// The element's accessibility label
    public let label: String?
    /// The element's value
    public let value: String?
    /// The element's description
    public let elementDescription: String?
    /// Frame in screen coordinates
    public let frame: ElementFrame?
    /// Whether the element is enabled
    public let isEnabled: Bool
    /// Whether the element is focused
    public let isFocused: Bool
    /// Available actions the element supports
    public let actions: [String]
    /// Child elements (for tree responses)
    public let children: [UIElementInfo]?

    public init(
        path: ElementPath,
        role: String,
        title: String? = nil,
        label: String? = nil,
        value: String? = nil,
        elementDescription: String? = nil,
        frame: ElementFrame? = nil,
        isEnabled: Bool = true,
        isFocused: Bool = false,
        actions: [String] = [],
        children: [UIElementInfo]? = nil
    ) {
        self.path = path
        self.role = role
        self.title = title
        self.label = label
        self.value = value
        self.elementDescription = elementDescription
        self.frame = frame
        self.isEnabled = isEnabled
        self.isFocused = isFocused
        self.actions = actions
        self.children = children
    }
}

// MARK: - Element Query

/// Query criteria for finding elements
public struct ElementQuery: Codable, Sendable {
    /// Filter by role (exact match)
    public let role: String?
    /// Filter by title containing this string (case-insensitive)
    public let titleContains: String?
    /// Filter by title (exact match)
    public let title: String?
    /// Filter by label containing this string (case-insensitive)
    public let labelContains: String?
    /// Filter by value containing this string (case-insensitive)
    public let valueContains: String?
    /// Maximum number of results to return (default: 50)
    public let maxResults: Int?

    public init(
        role: String? = nil,
        titleContains: String? = nil,
        title: String? = nil,
        labelContains: String? = nil,
        valueContains: String? = nil,
        maxResults: Int? = nil
    ) {
        self.role = role
        self.titleContains = titleContains
        self.title = title
        self.labelContains = labelContains
        self.valueContains = valueContains
        self.maxResults = maxResults
    }
}

// MARK: - Accessibility Action

/// Actions that can be performed on an element
public enum AccessibilityAction: String, Codable, Sendable {
    case press = "press"
    case setValue = "setValue"
    case focus = "focus"
    case confirm = "confirm"
    case cancel = "cancel"
    case increment = "increment"
    case decrement = "decrement"
    case showMenu = "showMenu"
    case pick = "pick"
}

// MARK: - Request Types

/// Request to get the UI element tree
public struct GetTreeRequest: Codable, Sendable {
    /// Process ID of the application (optional, uses frontmost if not specified)
    public let pid: Int32?
    /// Maximum depth of tree traversal (default: 5)
    public let maxDepth: Int?

    public init(pid: Int32? = nil, maxDepth: Int? = nil) {
        self.pid = pid
        self.maxDepth = maxDepth
    }
}

/// Request to find elements
public struct FindElementsRequest: Codable, Sendable {
    /// Process ID of the application (optional, uses frontmost if not specified)
    public let pid: Int32?
    /// Query criteria
    public let query: ElementQuery

    public init(pid: Int32? = nil, query: ElementQuery) {
        self.pid = pid
        self.query = query
    }
}

/// Request to perform an action on an element
public struct ActionRequest: Codable, Sendable {
    /// Path to the element
    public let path: ElementPath
    /// Action to perform
    public let action: AccessibilityAction
    /// Value for setValue action
    public let value: String?

    public init(path: ElementPath, action: AccessibilityAction, value: String? = nil) {
        self.path = path
        self.action = action
        self.value = value
    }
}

/// Request to get focused element
public struct GetFocusedRequest: Codable, Sendable {
    /// Process ID of the application (optional, uses frontmost if not specified)
    public let pid: Int32?

    public init(pid: Int32? = nil) {
        self.pid = pid
    }
}

// MARK: - Response Types

/// Response containing the UI tree
public struct GetTreeResponse: Codable, Sendable {
    public let success: Bool
    public let app: AppInfo?
    public let tree: UIElementInfo?
    public let error: String?

    public init(success: Bool, app: AppInfo? = nil, tree: UIElementInfo? = nil, error: String? = nil) {
        self.success = success
        self.app = app
        self.tree = tree
        self.error = error
    }
}

/// Response containing found elements
public struct FindElementsResponse: Codable, Sendable {
    public let success: Bool
    public let app: AppInfo?
    public let elements: [UIElementInfo]?
    public let count: Int
    public let error: String?

    public init(success: Bool, app: AppInfo? = nil, elements: [UIElementInfo]? = nil, count: Int = 0, error: String? = nil) {
        self.success = success
        self.app = app
        self.elements = elements
        self.count = count
        self.error = error
    }
}

/// Response from performing an action
public struct ActionResponse: Codable, Sendable {
    public let success: Bool
    public let action: String
    public let error: String?

    public init(success: Bool, action: String, error: String? = nil) {
        self.success = success
        self.action = action
        self.error = error
    }
}

/// Response containing focused element
public struct GetFocusedResponse: Codable, Sendable {
    public let success: Bool
    public let app: AppInfo?
    public let element: UIElementInfo?
    public let error: String?

    public init(success: Bool, app: AppInfo? = nil, element: UIElementInfo? = nil, error: String? = nil) {
        self.success = success
        self.app = app
        self.element = element
        self.error = error
    }
}

/// Response containing a single element
public struct GetElementResponse: Codable, Sendable {
    public let success: Bool
    public let app: AppInfo?
    public let element: UIElementInfo?
    public let error: String?

    public init(success: Bool, app: AppInfo? = nil, element: UIElementInfo? = nil, error: String? = nil) {
        self.success = success
        self.app = app
        self.element = element
        self.error = error
    }
}

// MARK: - Compact Tree

/// Compact element info for flattened tree output
public struct CompactElementInfo: Codable, Sendable {
    /// Path to locate this element
    public let path: ElementPath
    /// Accessibility role
    public let role: String
    /// Title (if present)
    public let title: String?
    /// Label (if present)
    public let label: String?
    /// Frame in screen coordinates
    public let frame: ElementFrame?
    /// Available actions
    public let actions: [String]?
    /// Tree depth for indentation
    public let depth: Int

    public init(
        path: ElementPath,
        role: String,
        title: String? = nil,
        label: String? = nil,
        frame: ElementFrame? = nil,
        actions: [String]? = nil,
        depth: Int = 0
    ) {
        self.path = path
        self.role = role
        self.title = title
        self.label = label
        self.frame = frame
        self.actions = actions
        self.depth = depth
    }
}

/// Response containing compact (flattened) UI tree
public struct GetCompactTreeResponse: Codable, Sendable {
    public let success: Bool
    public let app: AppInfo?
    /// Flattened list of elements (depth-first order)
    public let elements: [CompactElementInfo]?
    /// Total element count
    public let count: Int
    public let error: String?

    public init(success: Bool, app: AppInfo? = nil, elements: [CompactElementInfo]? = nil, count: Int = 0, error: String? = nil) {
        self.success = success
        self.app = app
        self.elements = elements
        self.count = count
        self.error = error
    }
}
