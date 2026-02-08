import Foundation
import AppKit
import ApplicationServices

/// Service for accessing and triggering application menus via accessibility
@MainActor
public final class MenuService {
    public static let shared = MenuService()

    private init() {}

    // MARK: - Public API

    /// Get the menu structure for an application
    /// - Parameter appName: The application name to get menus for
    /// - Returns: MenuResponse with the menu structure
    public func getMenus(appName: String) -> MenuResponse {
        // Find the application by name
        guard let app = findApp(byName: appName) else {
            return MenuResponse(success: false, error: "Application '\(appName)' not found or not running")
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Get the menu bar
        var menuBarRef: CFTypeRef?
        let menuBarResult = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef)

        guard menuBarResult == .success, let menuBar = menuBarRef as! AXUIElement? else {
            if menuBarResult == .apiDisabled {
                return MenuResponse(success: false, error: "Accessibility API is disabled")
            }
            return MenuResponse(success: false, error: "Could not access menu bar for '\(appName)'")
        }

        // Get menu bar children (top-level menus)
        var childrenRef: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &childrenRef)

        guard childrenResult == .success, let children = childrenRef as? [AXUIElement] else {
            return MenuResponse(success: false, error: "Could not access menu bar items")
        }

        // Build menu structure
        var menus: [MenuItemInfo] = []
        for child in children {
            if let menuInfo = buildMenuInfo(element: child, depth: 0, maxDepth: 3) {
                menus.append(menuInfo)
            }
        }

        return MenuResponse(success: true, menus: menus)
    }

    /// Trigger a menu item by path
    /// - Parameters:
    ///   - appName: The application name
    ///   - path: The menu path (e.g., ["File", "New Window"])
    ///   - background: If true, skip app activation to avoid bringing it to the foreground
    /// - Returns: MenuResponse indicating success or failure
    public func triggerMenu(appName: String, path: [String], background: Bool = false) -> MenuResponse {
        guard !path.isEmpty else {
            return MenuResponse(success: false, error: "Menu path cannot be empty")
        }

        // Find the application by name
        guard let app = findApp(byName: appName) else {
            return MenuResponse(success: false, error: "Application '\(appName)' not found or not running")
        }

        if !background {
            // Activate the app first (menus may not be accessible otherwise)
            app.activate()

            // Small delay to let the app activate
            Thread.sleep(forTimeInterval: 0.1)
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Get the menu bar
        var menuBarRef: CFTypeRef?
        let menuBarResult = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef)

        guard menuBarResult == .success, let menuBar = menuBarRef as! AXUIElement? else {
            return MenuResponse(success: false, error: "Could not access menu bar")
        }

        // Navigate to the menu item
        guard let menuItem = findMenuItem(in: menuBar, path: path) else {
            return MenuResponse(success: false, error: "Menu item not found: \(path.joined(separator: " > "))")
        }

        // Press the menu item
        let pressResult = AXUIElementPerformAction(menuItem, kAXPressAction as CFString)

        if pressResult == .success {
            return MenuResponse(success: true)
        } else {
            return MenuResponse(success: false, error: "Failed to trigger menu item (error: \(pressResult.rawValue))")
        }
    }

    // MARK: - Private Helpers

    private func findApp(byName name: String) -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications
        return apps.first { app in
            guard let appName = app.localizedName else { return false }
            return appName.localizedCaseInsensitiveCompare(name) == .orderedSame ||
                   appName.localizedCaseInsensitiveContains(name)
        }
    }

    private func buildMenuInfo(element: AXUIElement, depth: Int, maxDepth: Int) -> MenuItemInfo? {
        let title = getStringAttribute(element, kAXTitleAttribute) ?? ""

        // Skip empty/separator items
        if title.isEmpty || title == "AXMenuItemSeparator" {
            return nil
        }

        let isEnabled = getBoolAttribute(element, kAXEnabledAttribute) ?? true
        let shortcut = getMenuShortcut(element)

        // Check if this is a menu (has submenu)
        var submenuRef: CFTypeRef?
        let hasSubmenu = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &submenuRef) == .success &&
                        (submenuRef as? [AXUIElement])?.isEmpty == false

        // Get children if within depth limit and has submenu
        var children: [MenuItemInfo]? = nil
        if hasSubmenu && depth < maxDepth {
            if let submenuItems = submenuRef as? [AXUIElement] {
                children = submenuItems.compactMap { child in
                    // For menu bar items, the first child is usually the menu itself
                    // which contains the actual menu items
                    let role = getStringAttribute(child, kAXRoleAttribute)
                    if role == "AXMenu" {
                        // This is a submenu container, get its children
                        var menuChildrenRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &menuChildrenRef) == .success,
                           let menuChildren = menuChildrenRef as? [AXUIElement] {
                            return menuChildren.compactMap { buildMenuInfo(element: $0, depth: depth + 1, maxDepth: maxDepth) }
                        }
                        return nil
                    } else {
                        return [buildMenuInfo(element: child, depth: depth + 1, maxDepth: maxDepth)].compactMap { $0 }
                    }
                }.flatMap { $0 }

                if children?.isEmpty == true {
                    children = nil
                }
            }
        }

        return MenuItemInfo(
            title: title,
            isEnabled: isEnabled,
            hasSubmenu: hasSubmenu,
            shortcut: shortcut,
            children: children
        )
    }

    private func findMenuItem(in menuBar: AXUIElement, path: [String]) -> AXUIElement? {
        guard !path.isEmpty else { return nil }

        var currentElement: AXUIElement = menuBar
        var remainingPath = path

        while !remainingPath.isEmpty {
            let targetTitle = remainingPath.removeFirst()

            // Get children
            var childrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(currentElement, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                  let children = childrenRef as? [AXUIElement] else {
                return nil
            }

            // Find matching child
            var found = false
            for child in children {
                let childTitle = getStringAttribute(child, kAXTitleAttribute) ?? ""
                let childRole = getStringAttribute(child, kAXRoleAttribute)

                // Check if this child matches
                if childTitle.localizedCaseInsensitiveCompare(targetTitle) == .orderedSame ||
                   childTitle.localizedCaseInsensitiveContains(targetTitle) {

                    if remainingPath.isEmpty {
                        // This is the target menu item
                        return child
                    } else {
                        // Need to go deeper - find the submenu
                        if childRole == "AXMenu" {
                            currentElement = child
                        } else {
                            // Try to find AXMenu child
                            var submenuChildrenRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &submenuChildrenRef) == .success,
                               let submenuChildren = submenuChildrenRef as? [AXUIElement] {
                                for submenuChild in submenuChildren {
                                    let submenuRole = getStringAttribute(submenuChild, kAXRoleAttribute)
                                    if submenuRole == "AXMenu" {
                                        currentElement = submenuChild
                                        found = true
                                        break
                                    }
                                }
                            }
                            if found { break }
                            currentElement = child
                        }
                        found = true
                        break
                    }
                }

                // Also check if this is a menu container with matching children
                if childRole == "AXMenu" {
                    if let result = findMenuItem(in: child, path: [targetTitle] + remainingPath) {
                        return result
                    }
                }
            }

            if !found && !remainingPath.isEmpty {
                return nil
            }
        }

        return nil
    }

    private func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef)
        guard result == .success, let string = valueRef as? String else { return nil }
        return string.isEmpty ? nil : string
    }

    private func getBoolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef)
        guard result == .success else { return nil }

        if let number = valueRef as? NSNumber {
            return number.boolValue
        }
        return nil
    }

    private func getMenuShortcut(_ element: AXUIElement) -> String? {
        var cmdCharRef: CFTypeRef?
        let cmdCharResult = AXUIElementCopyAttributeValue(element, kAXMenuItemCmdCharAttribute as CFString, &cmdCharRef)

        guard cmdCharResult == .success, let cmdChar = cmdCharRef as? String, !cmdChar.isEmpty else {
            return nil
        }

        var modifiersRef: CFTypeRef?
        let modifiersResult = AXUIElementCopyAttributeValue(element, kAXMenuItemCmdModifiersAttribute as CFString, &modifiersRef)

        var shortcut = ""

        if modifiersResult == .success, let modifiers = modifiersRef as? Int {
            if modifiers & (1 << 0) != 0 { shortcut += "Ctrl+" }
            if modifiers & (1 << 1) != 0 { shortcut += "Opt+" }
            if modifiers & (1 << 2) != 0 { shortcut += "Shift+" }
            // Command is usually assumed for menu shortcuts
            shortcut += "Cmd+"
        } else {
            shortcut = "Cmd+"
        }

        shortcut += cmdChar

        return shortcut
    }
}
