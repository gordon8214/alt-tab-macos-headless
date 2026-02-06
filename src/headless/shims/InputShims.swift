import Foundation

class ATShortcut {
    static var lastEventIsARepeat = false
}

class KeyRepeatTimer {
    static var timerIsSuspended = true

    static func startRepeatingKeyPreviousWindow() {}

    static func startRepeatingKeyNextWindow() {}

    static func stopTimerForRepeatingKey(_ id: String = "") {}
}
