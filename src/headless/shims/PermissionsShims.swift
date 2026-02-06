import ApplicationServices.HIServices.AXUIElement

enum PermissionStatus {
    case granted
    case notGranted
    case skipped
}

class AccessibilityPermission {
    static var status = PermissionStatus.notGranted

    @discardableResult
    static func update() -> PermissionStatus {
        status = detect()
        return status
    }

    private static func detect() -> PermissionStatus {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .granted : .notGranted
    }
}

class ScreenRecordingPermission {
    static var status = PermissionStatus.notGranted

    @discardableResult
    static func update() -> PermissionStatus {
        status = .notGranted
        return status
    }
}
