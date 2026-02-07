import AppKit

class CliEvents {
    static let portName = "com.lwouis.alt-tab-macos.headless.cli"
    static let startupFailureMessage = "Can't listen on message port. Is another headless daemon already running?"

    @discardableResult
    static func observe() -> Bool {
        var context = CFMessagePortContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        if let messagePort = CFMessagePortCreateLocal(nil, portName as CFString, handleEvent, &context, nil),
           let source = CFMessagePortCreateRunLoopSource(nil, messagePort, 0) {
            CFRunLoopAddSource(BackgroundWork.cliEventsThread.runLoop, source, .commonModes)
            return true
        } else {
            return false
        }
    }

    private static let handleEvent: CFMessagePortCallBack = { (_: CFMessagePort?, _: Int32, _ data: CFData?, _: UnsafeMutableRawPointer?) in
        if let data,
           let message = String(data: data as Data, encoding: .utf8) {
            Logger.info { message }
            let output = CliServer.executeCommandAndSendResponse(message)
            if let responseData = try? CliServer.jsonEncoder.encode(output) as CFData {
                return Unmanaged.passRetained(responseData)
            }
        }
        Logger.error { "Failed to decode message" }
        return nil
    }
}

class CliServer {
    static let jsonEncoder = JSONEncoder()
    static let error = CliServerCode.error.rawValue
    static let noOutput = CliServerCode.noOutput.rawValue
    static let unsupported = CliServerCode.unsupported.rawValue
    static let warmingUpTimeout = CliServerCode.warmingUpTimeout.rawValue
    static let supportedCommandsMessage = "Supported commands: --list, --detailed-list, --focus=<window_id>, --focusUsingLastFocusOrder=<focus_order>, --show=<shortcut_index>, --help"
    private static let listingStateBootstrap: Void = {
        HeadlessListingState.refreshStateForListing = defaultRefreshStateForListing
        HeadlessListingState.windowSnapshotsProvider = defaultWindowSnapshotsProvider
    }()

    static func executeCommandAndSendResponse(_ rawValue: String) -> Codable {
        if let preflightCode = HeadlessCliPolicy.preflightCode(for: rawValue) {
            return preflightCode.rawValue
        }

        var output: Codable = ""
        DispatchQueue.main.sync {
            output = executeCommandAndSendResponse_(rawValue)
        }
        return output
    }

    private static func executeCommandAndSendResponse_(_ rawValue: String) -> Codable {
        guard let command = CliShared.parseServerCommand(rawValue, support: .headlessServer) else {
            return error
        }

        switch command {
        case .list:
            let windows = refreshedVisibleSnapshots()
            return JsonWindowList(windows: windows.map { JsonWindow(id: $0.id, title: $0.title) })

        case .detailedList:
            let windows = refreshedVisibleSnapshots()
            return JsonWindowFullList(windows: windows.map {
                JsonWindowFull(
                    id: $0.id,
                    title: $0.title,
                    appName: $0.appName,
                    appBundleId: $0.appBundleId,
                    spaceIndexes: $0.spaceIndexes,
                    lastFocusOrder: $0.lastFocusOrder,
                    creationOrder: $0.creationOrder,
                    isTabbed: $0.isTabbed,
                    isHidden: $0.isHidden,
                    isFullscreen: $0.isFullscreen,
                    isMinimized: $0.isMinimized,
                    isOnAllSpaces: $0.isOnAllSpaces,
                    position: $0.position,
                    size: $0.size
                )
            })

        case .focus(let id):
            let windows = refreshedWindowsForInteractiveCommands()
            let windowsForSelection = selectableWindows(windows)
            guard let selectedWindowIndex = HeadlessCliCommandResolver.resolveWindowListIndex(
                for: .focus(id),
                windows: windowsForSelection
            ),
                windows.indices.contains(selectedWindowIndex) else {
                return error
            }
            windows[selectedWindowIndex].focus()
            return noOutput

        case .focusUsingLastFocusOrder(let lastFocusOrder):
            let windows = refreshedWindowsForInteractiveCommands()
            let windowsForSelection = selectableWindows(windows)
            guard let selectedWindowIndex = HeadlessCliCommandResolver.resolveWindowListIndex(
                for: .focusUsingLastFocusOrder(lastFocusOrder),
                windows: windowsForSelection
            ),
                windows.indices.contains(selectedWindowIndex) else {
                return error
            }
            windows[selectedWindowIndex].focus()
            return noOutput

        case .show(let shortcutIndex):
            return focusFromHeadlessShow(shortcutIndex) ? noOutput : error

        case .help:
            return error
        }
    }

    private static func refreshedVisibleSnapshots() -> [HeadlessWindowSnapshot] {
        _ = listingStateBootstrap
        return HeadlessListingState.refreshedVisibleSnapshots()
    }

    private static func defaultRefreshStateForListing() {
        NSScreen.updatePreferred()
        Spaces.refresh()
        Screens.refresh()
        for window in Windows.list where !window.isWindowlessApp {
            window.updateSpacesAndScreen()
        }
    }

    private static func focusFromHeadlessShow(_ shortcutIndex: Int) -> Bool {
        guard let preferences = headlessShowSelectionPreferences(shortcutIndex) else {
            return false
        }

        App.app.shortcutIndex = shortcutIndex
        let windows = refreshedWindowsForInteractiveCommands()
        let windowsForSelection = selectableWindows(windows)
        let frontmostPid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let visibleSpaces = Spaces.visibleSpaces.map { UInt64($0) }
        guard let selectedWindowIndex = HeadlessCliCommandResolver.resolveWindowListIndex(
            for: .show(shortcutIndex),
            windows: windowsForSelection,
            showPreferences: preferences,
            frontmostPid: frontmostPid,
            visibleSpaces: visibleSpaces
        ),
            windows.indices.contains(selectedWindowIndex) else {
            return false
        }
        windows[selectedWindowIndex].focus()
        return true
    }

    private static func refreshedWindowsForInteractiveCommands() -> [Window] {
        defaultRefreshStateForListing()
        return Windows.list
    }

    private static func headlessShowSelectionPreferences(_ shortcutIndex: Int) -> HeadlessShowSelectionPreferences? {
        guard let appsToShow = preferenceValue(Preferences.appsToShow, at: shortcutIndex),
              let spacesToShow = preferenceValue(Preferences.spacesToShow, at: shortcutIndex),
              let screensToShow = preferenceValue(Preferences.screensToShow, at: shortcutIndex),
              let showMinimizedWindows = preferenceValue(Preferences.showMinimizedWindows, at: shortcutIndex),
              let showHiddenWindows = preferenceValue(Preferences.showHiddenWindows, at: shortcutIndex),
              let showFullscreenWindows = preferenceValue(Preferences.showFullscreenWindows, at: shortcutIndex),
              let showWindowlessApps = preferenceValue(Preferences.showWindowlessApps, at: shortcutIndex),
              let windowOrder = preferenceValue(Preferences.windowOrder, at: shortcutIndex) else {
            return nil
        }
        return HeadlessShowSelectionPreferences(
            appsToShow: mapAppsToShow(appsToShow),
            spacesToShow: mapSpacesToShow(spacesToShow),
            screensToShow: mapScreensToShow(screensToShow),
            showMinimizedWindows: mapShowHow(showMinimizedWindows),
            showHiddenWindows: mapShowHow(showHiddenWindows),
            showFullscreenWindows: mapShowHow(showFullscreenWindows),
            showWindowlessApps: mapShowHow(showWindowlessApps),
            windowOrder: mapWindowOrder(windowOrder),
            showTabsAsWindows: Preferences.showTabsAsWindows,
            onlyShowApplications: Preferences.onlyShowApplications(),
            blacklist: Preferences.blacklist.map {
                HeadlessShowBlacklistEntry(
                    bundleIdentifier: $0.bundleIdentifier,
                    hide: mapBlacklistHide($0.hide)
                )
            }
        )
    }

    private static func preferenceValue<T>(_ values: [T], at index: Int) -> T? {
        values.indices.contains(index) ? values[index] : nil
    }

    private static func selectableWindows(_ windows: [Window]) -> [HeadlessShowSelectionWindow] {
        windows.enumerated().map { headlessShowSelectionWindow($0.element, windowListIndex: $0.offset) }
    }

    private static func headlessShowSelectionWindow(_ window: Window, windowListIndex: Int) -> HeadlessShowSelectionWindow {
        HeadlessShowSelectionWindow(
            windowListIndex: windowListIndex,
            windowId: window.id,
            cgWindowId: window.cgWindowId,
            title: window.title,
            appName: window.application.localizedName,
            appBundleId: window.application.bundleIdentifier,
            appPid: window.application.pid,
            spaceIds: window.spaceIds.map { UInt64($0) },
            spaceIndexes: window.spaceIndexes,
            lastFocusOrder: window.lastFocusOrder,
            creationOrder: window.creationOrder,
            isTabbed: window.isTabbed,
            isHidden: window.isHidden,
            isFullscreen: window.isFullscreen,
            isMinimized: window.isMinimized,
            isOnAllSpaces: window.isOnAllSpaces,
            isWindowlessApp: window.isWindowlessApp,
            isOnPreferredScreen: window.isOnScreen(NSScreen.preferred)
        )
    }

    private static func mapAppsToShow(_ value: AppsToShowPreference) -> HeadlessShowAppsToShow {
        switch value {
        case .all:
            return .all
        case .active:
            return .active
        case .nonActive:
            return .nonActive
        }
    }

    private static func mapSpacesToShow(_ value: SpacesToShowPreference) -> HeadlessShowSpacesToShow {
        switch value {
        case .all:
            return .all
        case .visible:
            return .visible
        }
    }

    private static func mapScreensToShow(_ value: ScreensToShowPreference) -> HeadlessShowScreensToShow {
        switch value {
        case .all:
            return .all
        case .showingAltTab:
            return .showingAltTab
        }
    }

    private static func mapShowHow(_ value: ShowHowPreference) -> HeadlessShowHow {
        switch value {
        case .hide:
            return .hide
        case .show:
            return .show
        case .showAtTheEnd:
            return .showAtTheEnd
        }
    }

    private static func mapWindowOrder(_ value: WindowOrderPreference) -> HeadlessWindowOrder {
        switch value {
        case .recentlyFocused:
            return .recentlyFocused
        case .recentlyCreated:
            return .recentlyCreated
        case .alphabetical:
            return .alphabetical
        case .space:
            return .space
        }
    }

    private static func mapBlacklistHide(_ value: BlacklistHidePreference) -> HeadlessShowBlacklistHide {
        switch value {
        case .always:
            return .always
        case .whenNoOpenWindow:
            return .whenWindowless
        case .none:
            return .none
        }
    }

    private static func defaultWindowSnapshotsProvider() -> [HeadlessWindowSnapshot] {
        Windows.list.map { HeadlessWindowSnapshot(window: $0) }
    }

    private struct JsonWindowList: Codable {
        var windows: [JsonWindow]
    }

    private struct JsonWindow: Codable {
        var id: CGWindowID?
        var title: String
    }

    private struct JsonWindowFullList: Codable {
        var windows: [JsonWindowFull]
    }

    private struct JsonWindowFull: Codable {
        var id: CGWindowID?
        var title: String
        var appName: String?
        var appBundleId: String?
        var spaceIndexes: [SpaceIndex]
        var lastFocusOrder: Int
        var creationOrder: Int
        var isTabbed: Bool
        var isHidden: Bool
        var isFullscreen: Bool
        var isMinimized: Bool
        var isOnAllSpaces: Bool
        var position: CGPoint?
        var size: CGSize?
    }
}

private extension HeadlessWindowSnapshot {
    init(window: Window) {
        id = window.cgWindowId
        title = window.title
        appName = window.application.localizedName
        appBundleId = window.application.bundleIdentifier
        spaceIndexes = window.spaceIndexes
        lastFocusOrder = window.lastFocusOrder
        creationOrder = window.creationOrder
        isTabbed = window.isTabbed
        isHidden = window.isHidden
        isFullscreen = window.isFullscreen
        isMinimized = window.isMinimized
        isOnAllSpaces = window.isOnAllSpaces
        position = window.position
        size = window.size
        isWindowlessApp = window.isWindowlessApp
    }
}

class CliClient {
    static func detectMode() -> CliClientMode {
        CliShared.detectClientMode(arguments: CommandLine.arguments, support: .headlessClient)
    }

    static func printHelp() {
        print("Usage: AltTabHeadless [--list | --detailed-list | --focus=<window_id> | --focusUsingLastFocusOrder=<focus_order> | --show=<shortcut_index> | --help]")
        print("Run with no arguments to start the headless daemon.")
    }

    static func sendCommandAndProcessResponse(_ command: String) {
        do {
            let serverPortClient = try CFMessagePortCreateRemote(nil, CliEvents.portName as CFString).unwrapOrThrow()
            let data = try command.data(using: .utf8).unwrapOrThrow()
            var returnData: Unmanaged<CFData>?
            let _ = CFMessagePortSendRequest(serverPortClient, 0, data as CFData, 7, 7, CFRunLoopMode.defaultMode.rawValue, &returnData)
            let responseData = try returnData.unwrapOrThrow().takeRetainedValue()
            if let response = String(data: responseData as Data, encoding: .utf8) {
                if response == "\"\(CliServer.error)\"" {
                    print("Couldn't execute command. Is it correct?")
                    exit(1)
                }
                if response == "\"\(CliServer.unsupported)\"" {
                    print("Unsupported command in headless mode. \(CliServer.supportedCommandsMessage)")
                    exit(1)
                }
                if response == "\"\(CliServer.warmingUpTimeout)\"" {
                    print("Headless daemon is still warming up. Try again in a few seconds.")
                    exit(1)
                }
                if response != "\"\(CliServer.noOutput)\"" {
                    print(response)
                }
                exit(0)
            }
            print("Failed to decode command response")
            exit(1)
        } catch {
            print("AltTabHeadless daemon needs to be running for CLI commands to work")
            exit(1)
        }
    }
}
