import Foundation

enum ShowOnScreenPreference {
    case includingMouse
    case active
    case includingMenubar
}

enum ShowAppsOrWindowsPreference {
    case windows
    case applications
}

enum AppsToShowPreference {
    case all
    case active
    case nonActive
}

enum SpacesToShowPreference {
    case all
    case visible
}

enum ScreensToShowPreference {
    case all
    case showingAltTab
}

enum ShowHowPreference {
    case hide
    case show
    case showAtTheEnd
}

enum WindowOrderPreference {
    case recentlyFocused
    case recentlyCreated
    case alphabetical
    case space
}

enum AppearanceThemePreference {
    case system
    case light
    case dark
}

enum BlacklistHidePreference {
    case always
    case whenNoOpenWindow
    case none
}

enum BlacklistIgnorePreference {
    case whenFullscreen
    case none
}

struct BlacklistEntry {
    var bundleIdentifier: String
    var hide: BlacklistHidePreference
    var ignore: BlacklistIgnorePreference
}

class Preferences {
    static var finderShowsQuitMenuItem: Bool { false }
    static var hideAppBadges: Bool { true }
    static var previewSelectedWindow: Bool { false }
    static var showTabsAsWindows: Bool { false }
    static var mouseHoverEnabled: Bool { false }

    static var blacklist: [BlacklistEntry] { [] }
    static var showOnScreen: ShowOnScreenPreference { .active }
    static var appsToShow: [AppsToShowPreference] { [.all, .active, .nonActive, .all] }
    static var spacesToShow: [SpacesToShowPreference] { [.all, .all, .all, .all] }
    static var screensToShow: [ScreensToShowPreference] { [.all, .all, .all, .all] }
    static var showMinimizedWindows: [ShowHowPreference] { [.show, .show, .show, .show] }
    static var showHiddenWindows: [ShowHowPreference] { [.show, .show, .show, .show] }
    static var showFullscreenWindows: [ShowHowPreference] { [.show, .show, .show, .show] }
    static var showWindowlessApps: [ShowHowPreference] { [.showAtTheEnd, .showAtTheEnd, .showAtTheEnd, .showAtTheEnd] }
    static var windowOrder: [WindowOrderPreference] { [.recentlyFocused, .recentlyFocused, .recentlyFocused, .recentlyFocused] }

    static func initialize() {
        // intentionally no-op in headless mode
    }

    static func onlyShowApplications() -> Bool {
        false
    }
}
