import Foundation
import AppKit
import ApplicationServices

/// Service for macOS accessibility (AXUIElement) operations
@MainActor
public final class AccessibilityService {
    public static let shared = AccessibilityService()

    /// Default maximum depth for tree traversal
    public static let defaultMaxDepth = 5
    /// Default maximum search results
    public static let defaultMaxResults = 50
    /// Operation timeout in seconds
    public static let operationTimeout: TimeInterval = 5.0

    private init() {}

    // MARK: - Public API

    /// Get the UI element tree for an application
    /// - Parameters:
    ///   - pid: Process ID (uses frontmost app if nil)
    ///   - maxDepth: Maximum tree depth (default: 5)
    /// - Returns: GetTreeResponse with the UI tree
    public func getTree(pid: Int32?, maxDepth: Int?) -> GetTreeResponse {
        let effectiveMaxDepth = maxDepth ?? Self.defaultMaxDepth

        // Get the app element
        let (appElement, appInfo, error) = getAppElement(pid: pid)
        guard let appElement = appElement, let appInfo = appInfo else {
            return GetTreeResponse(success: false, error: error ?? "Failed to get application element")
        }

        // Build the tree
        let tree = buildElementInfo(element: appElement, pid: appInfo.processIdentifier, path: [], depth: 0, maxDepth: effectiveMaxDepth)

        return GetTreeResponse(success: true, app: appInfo, tree: tree)
    }

    /// Get a compact (flattened) UI element list for an application
    /// - Parameters:
    ///   - pid: Process ID (uses frontmost app if nil)
    ///   - maxDepth: Maximum tree depth (default: 5)
    ///   - includeActions: Whether to include actions in output (default: true)
    /// - Returns: GetCompactTreeResponse with flattened element list
    public func getCompactTree(pid: Int32?, maxDepth: Int?, includeActions: Bool = true) -> GetCompactTreeResponse {
        let effectiveMaxDepth = maxDepth ?? Self.defaultMaxDepth

        // Get the app element
        let (appElement, appInfo, error) = getAppElement(pid: pid)
        guard let appElement = appElement, let appInfo = appInfo else {
            return GetCompactTreeResponse(success: false, error: error ?? "Failed to get application element")
        }

        // Flatten the tree
        var elements: [CompactElementInfo] = []
        flattenTree(
            element: appElement,
            pid: appInfo.processIdentifier,
            path: [],
            depth: 0,
            maxDepth: effectiveMaxDepth,
            includeActions: includeActions,
            results: &elements
        )

        return GetCompactTreeResponse(
            success: true,
            app: appInfo,
            elements: elements,
            count: elements.count
        )
    }

    /// Flatten tree into a list (depth-first order)
    private func flattenTree(
        element: AXUIElement,
        pid: Int32,
        path: [Int],
        depth: Int,
        maxDepth: Int,
        includeActions: Bool,
        results: inout [CompactElementInfo]
    ) {
        // Get basic attributes
        let role = getStringAttribute(element, kAXRoleAttribute) ?? "Unknown"
        let title = getStringAttribute(element, kAXTitleAttribute)
        let label = getStringAttribute(element, kAXDescriptionAttribute)
        let frame = getFrame(element)
        let actions: [String]? = includeActions ? getActions(element) : nil

        // Only include elements that have some identifying info (title, label, or meaningful role)
        let meaningfulRoles = ["AXButton", "AXTextField", "AXTextArea", "AXLink", "AXCheckBox", "AXRadioButton",
                               "AXPopUpButton", "AXComboBox", "AXSlider", "AXTabGroup", "AXTable", "AXList",
                               "AXMenuItem", "AXMenu", "AXMenuBar", "AXMenuButton", "AXToolbar", "AXSheet",
                               "AXDialog", "AXWindow", "AXStaticText", "AXImage", "AXScrollArea"]

        let hasText = (title != nil && !title!.isEmpty) || (label != nil && !label!.isEmpty)
        let isMeaningfulRole = meaningfulRoles.contains(role)

        // Include if it has text OR is a meaningful interactive role
        if hasText || isMeaningfulRole {
            let compactInfo = CompactElementInfo(
                path: ElementPath(pid: pid, path: path),
                role: role,
                title: title,
                label: label,
                frame: frame,
                actions: actions?.isEmpty == true ? nil : actions,
                depth: depth
            )
            results.append(compactInfo)
        }

        // Recurse into children if within depth limit
        guard depth < maxDepth else { return }

        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)

        guard result == .success, let children = childrenRef as? [AXUIElement] else { return }

        for (index, child) in children.enumerated() {
            let childPath = path + [index]
            flattenTree(
                element: child,
                pid: pid,
                path: childPath,
                depth: depth + 1,
                maxDepth: maxDepth,
                includeActions: includeActions,
                results: &results
            )
        }
    }

    /// Find elements matching query criteria
    /// - Parameters:
    ///   - pid: Process ID (uses frontmost app if nil)
    ///   - query: Search criteria
    /// - Returns: FindElementsResponse with matching elements
    public func findElements(pid: Int32?, query: ElementQuery) -> FindElementsResponse {
        let maxResults = query.maxResults ?? Self.defaultMaxResults

        // Get the app element
        let (appElement, appInfo, error) = getAppElement(pid: pid)
        guard let appElement = appElement, let appInfo = appInfo else {
            return FindElementsResponse(success: false, error: error ?? "Failed to get application element")
        }

        // Search for matching elements
        var results: [UIElementInfo] = []
        searchElements(
            element: appElement,
            pid: appInfo.processIdentifier,
            path: [],
            query: query,
            maxResults: maxResults,
            results: &results
        )

        return FindElementsResponse(
            success: true,
            app: appInfo,
            elements: results,
            count: results.count
        )
    }

    /// Get the currently focused element
    /// - Parameter pid: Process ID (uses frontmost app if nil)
    /// - Returns: GetFocusedResponse with the focused element
    public func getFocusedElement(pid: Int32?) -> GetFocusedResponse {
        // Get the app element
        let (appElement, appInfo, error) = getAppElement(pid: pid)
        guard let appElement = appElement, let appInfo = appInfo else {
            return GetFocusedResponse(success: false, error: error ?? "Failed to get application element")
        }

        // Get focused element
        var focusedRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef)

        guard focusedResult == .success, let focusedElement = focusedRef as! AXUIElement? else {
            return GetFocusedResponse(success: true, app: appInfo, element: nil)
        }

        // Find the path to this element
        let path = findPathToElement(appElement: appElement, targetElement: focusedElement, currentPath: [])

        // Build element info
        let elementInfo = buildElementInfo(
            element: focusedElement,
            pid: appInfo.processIdentifier,
            path: path ?? [],
            depth: 0,
            maxDepth: 0 // Don't include children
        )

        return GetFocusedResponse(success: true, app: appInfo, element: elementInfo)
    }

    /// Perform an action on an element
    /// - Parameters:
    ///   - path: Path to the element
    ///   - action: Action to perform
    ///   - value: Value for setValue action
    /// - Returns: ActionResponse
    public func performAction(path: ElementPath, action: AccessibilityAction, value: String?) -> ActionResponse {
        // Get the app element
        let appElement = AXUIElementCreateApplication(path.pid)

        // Navigate to the target element
        guard let targetElement = navigateToElement(from: appElement, path: path.path) else {
            return ActionResponse(success: false, action: action.rawValue, error: "Element not found at path")
        }

        // Perform the action
        var actionResult: AXError = .failure

        switch action {
        case .press:
            actionResult = AXUIElementPerformAction(targetElement, kAXPressAction as CFString)

        case .setValue:
            guard let newValue = value else {
                return ActionResponse(success: false, action: action.rawValue, error: "Value required for setValue action")
            }
            actionResult = AXUIElementSetAttributeValue(targetElement, kAXValueAttribute as CFString, newValue as CFTypeRef)

        case .focus:
            actionResult = AXUIElementSetAttributeValue(targetElement, kAXFocusedAttribute as CFString, true as CFTypeRef)

        case .confirm:
            actionResult = AXUIElementPerformAction(targetElement, kAXConfirmAction as CFString)

        case .cancel:
            actionResult = AXUIElementPerformAction(targetElement, kAXCancelAction as CFString)

        case .increment:
            actionResult = AXUIElementPerformAction(targetElement, kAXIncrementAction as CFString)

        case .decrement:
            actionResult = AXUIElementPerformAction(targetElement, kAXDecrementAction as CFString)

        case .showMenu:
            actionResult = AXUIElementPerformAction(targetElement, kAXShowMenuAction as CFString)

        case .pick:
            actionResult = AXUIElementPerformAction(targetElement, kAXPickAction as CFString)
        }

        if actionResult == .success {
            return ActionResponse(success: true, action: action.rawValue)
        } else {
            return ActionResponse(
                success: false,
                action: action.rawValue,
                error: "Action failed with error code: \(actionResult.rawValue)"
            )
        }
    }

    /// Get the frame of an element at a given path
    /// - Parameter path: Path to the element
    /// - Returns: ElementFrame if found, nil otherwise
    public func findElementFrame(path: ElementPath) -> ElementFrame? {
        let appElement = AXUIElementCreateApplication(path.pid)
        guard let targetElement = navigateToElement(from: appElement, path: path.path) else {
            return nil
        }
        return getFrame(targetElement)
    }

    // MARK: - Private Helpers

    /// Get the AXUIElement for an application
    private func getAppElement(pid: Int32?) -> (AXUIElement?, AppInfo?, String?) {
        let effectivePid: Int32

        if let pid = pid {
            effectivePid = pid
        } else {
            // Get frontmost app
            guard let frontApp = NSWorkspace.shared.frontmostApplication else {
                return (nil, nil, "No frontmost application")
            }
            effectivePid = frontApp.processIdentifier
        }

        // Verify the process exists
        guard let app = NSRunningApplication(processIdentifier: effectivePid) else {
            return (nil, nil, "Application with PID \(effectivePid) not found")
        }

        let appInfo = AppInfo(
            name: app.localizedName ?? "Unknown",
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: effectivePid
        )

        let appElement = AXUIElementCreateApplication(effectivePid)

        // Verify we can access the app
        var roleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXRoleAttribute as CFString, &roleRef)

        if result != .success {
            if result == .apiDisabled {
                return (nil, nil, "Accessibility API is disabled. Enable it in System Settings > Privacy & Security > Accessibility")
            } else if result == .cannotComplete {
                return (nil, nil, "Cannot access application. It may not support accessibility or may require permissions")
            }
            return (nil, nil, "Failed to access application (error: \(result.rawValue))")
        }

        return (appElement, appInfo, nil)
    }

    /// Build UIElementInfo from an AXUIElement
    private func buildElementInfo(element: AXUIElement, pid: Int32, path: [Int], depth: Int, maxDepth: Int) -> UIElementInfo {
        // Get basic attributes
        let role = getStringAttribute(element, kAXRoleAttribute) ?? "Unknown"
        let title = getStringAttribute(element, kAXTitleAttribute)
        let label = getStringAttribute(element, kAXDescriptionAttribute)
        let value = getStringAttribute(element, kAXValueAttribute)
        let description = getStringAttribute(element, kAXHelpAttribute)

        // Get frame
        let frame = getFrame(element)

        // Get enabled/focused state
        let isEnabled = getBoolAttribute(element, kAXEnabledAttribute) ?? true
        let isFocused = getBoolAttribute(element, kAXFocusedAttribute) ?? false

        // Get available actions
        let actions = getActions(element)

        // Get children if within depth limit
        var children: [UIElementInfo]? = nil
        if depth < maxDepth {
            children = getChildElements(element, pid: pid, parentPath: path, depth: depth, maxDepth: maxDepth)
        }

        return UIElementInfo(
            path: ElementPath(pid: pid, path: path),
            role: role,
            title: title,
            label: label,
            value: value,
            elementDescription: description,
            frame: frame,
            isEnabled: isEnabled,
            isFocused: isFocused,
            actions: actions,
            children: children
        )
    }

    /// Get child elements
    private func getChildElements(_ element: AXUIElement, pid: Int32, parentPath: [Int], depth: Int, maxDepth: Int) -> [UIElementInfo]? {
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)

        guard result == .success, let children = childrenRef as? [AXUIElement], !children.isEmpty else {
            return nil
        }

        var childInfos: [UIElementInfo] = []
        for (index, child) in children.enumerated() {
            let childPath = parentPath + [index]
            let childInfo = buildElementInfo(element: child, pid: pid, path: childPath, depth: depth + 1, maxDepth: maxDepth)
            childInfos.append(childInfo)
        }

        return childInfos.isEmpty ? nil : childInfos
    }

    /// Search for elements matching query
    private func searchElements(
        element: AXUIElement,
        pid: Int32,
        path: [Int],
        query: ElementQuery,
        maxResults: Int,
        results: inout [UIElementInfo]
    ) {
        // Check if we've hit the limit
        guard results.count < maxResults else { return }

        // Get element attributes
        let role = getStringAttribute(element, kAXRoleAttribute) ?? ""
        let title = getStringAttribute(element, kAXTitleAttribute)
        let label = getStringAttribute(element, kAXDescriptionAttribute)
        let value = getStringAttribute(element, kAXValueAttribute)

        // Check if element matches query
        var matches = true

        if let queryRole = query.role, !queryRole.isEmpty {
            matches = matches && role == queryRole
        }

        if let queryTitle = query.title {
            matches = matches && (title == queryTitle)
        }

        if let titleContains = query.titleContains, !titleContains.isEmpty {
            matches = matches && (title?.localizedCaseInsensitiveContains(titleContains) ?? false)
        }

        if let labelContains = query.labelContains, !labelContains.isEmpty {
            matches = matches && (label?.localizedCaseInsensitiveContains(labelContains) ?? false)
        }

        if let valueContains = query.valueContains, !valueContains.isEmpty {
            matches = matches && (value?.localizedCaseInsensitiveContains(valueContains) ?? false)
        }

        // Add to results if matches
        if matches && hasQueryCriteria(query) {
            let info = buildElementInfo(element: element, pid: pid, path: path, depth: 0, maxDepth: 0)
            results.append(info)
        }

        // Recursively search children
        guard results.count < maxResults else { return }

        var childrenRef: CFTypeRef?
        let childResult = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)

        guard childResult == .success, let children = childrenRef as? [AXUIElement] else { return }

        for (index, child) in children.enumerated() {
            guard results.count < maxResults else { break }
            let childPath = path + [index]
            searchElements(element: child, pid: pid, path: childPath, query: query, maxResults: maxResults, results: &results)
        }
    }

    /// Check if query has any criteria
    private func hasQueryCriteria(_ query: ElementQuery) -> Bool {
        return query.role != nil ||
               query.title != nil ||
               query.titleContains != nil ||
               query.labelContains != nil ||
               query.valueContains != nil
    }

    /// Navigate to an element using path indices
    private func navigateToElement(from root: AXUIElement, path: [Int]) -> AXUIElement? {
        var current = root

        for index in path {
            var childrenRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(current, kAXChildrenAttribute as CFString, &childrenRef)

            guard result == .success, let children = childrenRef as? [AXUIElement] else {
                return nil
            }

            guard index >= 0 && index < children.count else {
                return nil
            }

            current = children[index]
        }

        return current
    }

    /// Find the path to a specific element (used for focused element)
    private func findPathToElement(appElement: AXUIElement, targetElement: AXUIElement, currentPath: [Int]) -> [Int]? {
        // Check if current element is the target
        if CFEqual(appElement, targetElement) {
            return currentPath
        }

        // Get children
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &childrenRef)

        guard result == .success, let children = childrenRef as? [AXUIElement] else {
            return nil
        }

        // Search children
        for (index, child) in children.enumerated() {
            let childPath = currentPath + [index]
            if let foundPath = findPathToElement(appElement: child, targetElement: targetElement, currentPath: childPath) {
                return foundPath
            }
        }

        return nil
    }

    // MARK: - Attribute Helpers

    private func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef)
        guard result == .success else { return nil }

        if let string = valueRef as? String {
            return string.isEmpty ? nil : string
        }

        // Try to convert other types to string
        if let number = valueRef as? NSNumber {
            return number.stringValue
        }

        return nil
    }

    private func getBoolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef)
        guard result == .success else { return nil }

        if let number = valueRef as? NSNumber {
            return number.boolValue
        }
        if let value = valueRef as? Bool {
            return value
        }

        return nil
    }

    private func getFrame(_ element: AXUIElement) -> ElementFrame? {
        // Get position
        var positionRef: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)

        // Get size
        var sizeRef: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)

        guard posResult == .success, sizeResult == .success,
              let posValue = positionRef as! AXValue?,
              let sizeValue = sizeRef as! AXValue? else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(posValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }

        return ElementFrame(
            x: Double(position.x),
            y: Double(position.y),
            width: Double(size.width),
            height: Double(size.height)
        )
    }

    private func getActions(_ element: AXUIElement) -> [String] {
        var actionsRef: CFArray?
        let result = AXUIElementCopyActionNames(element, &actionsRef)

        guard result == .success, let actions = actionsRef as? [String] else {
            return []
        }

        return actions
    }
}
