import Cocoa

class WindowCaptureScreenshots {
    static func oneTimeScreenshots(_ windowsToScreenshot: [Window], _ source: RefreshCausedBy) {}
}

class WindowCaptureScreenshotsPrivateApi {
    static func oneTimeScreenshots(_ eligibleWindows: [Window], _ source: RefreshCausedBy) {}
}

class ActiveWindowCaptures {
    static func increment() {}

    static func decrement() {}

    static func value() -> Int {
        return 0
    }
}
