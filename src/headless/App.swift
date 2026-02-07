import Cocoa

class App: NSApplication {
    static let bundleIdentifier = Bundle.main.bundleIdentifier!
    static let bundleURL = Bundle.main.bundleURL
    static let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    static let licence = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as! String
    static var app: App!

    var isTerminating = false
    var thumbnailsPanel = ThumbnailsPanel()
    var previewPanel = PreviewPanel()
    var appIsBeingUsed = false
    var shortcutIndex = 0
    var forceDoNothingOnRelease = false

    override init() {
        super.init()
        delegate = self
        App.app = self
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    func refreshOpenUi(_ windowsToScreenshot: [Window], _ source: RefreshCausedBy, windowRemoved: Bool = false) {
        // no-op in headless mode; screenshots/UI refresh are intentionally disabled
    }

    func checkIfShortcutsShouldBeDisabled(_ activeWindow: Window?, _ activeApp: Application?) {}

    func resetPreferencesDependentComponents() {}

    func hideUi(_ keepPreview: Bool = false) {
        appIsBeingUsed = false
    }

    func restart() {
        Logger.error { "Headless restart requested; terminating process" }
        terminate(nil)
    }

    private func failFast(_ message: String) {
        Logger.error { message }
        fputs(message + "\n", stderr)
        exit(1)
    }

    private func markReadyAfterInitialDiscovery() {
        BackgroundWork.axCallsManualDiscoveryQueue.addOperation {
            ReadinessGate.markReady()
            Logger.info { "Headless initial discovery ready" }
        }
    }

    private func ensureGuiAltTabIsNotRunning() {
        _ = HeadlessStartupConflictGuard.enforceNoGuiAltTabRunning(
            runningAppsProvider: {
                NSWorkspace.shared.runningApplications.map {
                    HeadlessRunningAppSnapshot(
                        pid: $0.processIdentifier,
                        bundleIdentifier: $0.bundleIdentifier,
                        isTerminated: $0.isTerminated
                    )
                }
            },
            currentPidProvider: { ProcessInfo.processInfo.processIdentifier },
            presentConflictAlert: { _ in
                self.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = NSLocalizedString("AltTab is already running", comment: "")
                alert.informativeText = NSLocalizedString("AltTabHeadless can't run while the full AltTab app is running. Quit AltTab and relaunch AltTabHeadless.", comment: "")
                alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))
                _ = alert.runModal()
            },
            failFast: { message in
                self.failFast(message)
            }
        )
    }

    private func showAccessibilityPermissionAlert(_ appPath: String) -> NSApplication.ModalResponse {
        // LSUIElement apps may fail to surface modal alerts consistently without becoming regular first.
        let wasRegular = activationPolicy() == .regular
        if !wasRegular {
            _ = setActivationPolicy(.regular)
        }
        defer {
            if !wasRegular {
                _ = setActivationPolicy(.accessory)
            }
        }

        activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = NSLocalizedString("AltTab needs some permissions", comment: "")
        alert.informativeText = """
\(NSLocalizedString("This permission is needed to focus windows after you release the shortcut", comment: ""))

App path: \(appPath)
"""
        alert.addButton(withTitle: NSLocalizedString("Open Accessibility Settings…", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Open System Settings to confirm, and continue", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Quit", comment: ""))
        return alert.runModal()
    }

    private func ensureAccessibilityPermission() -> Bool {
        let settingsUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        let appPath = Bundle.main.bundlePath
        while AccessibilityPermission.update() != .granted {
            switch showAccessibilityPermissionAlert(appPath) {
            case .alertFirstButtonReturn:
                if let settingsUrl {
                    NSWorkspace.shared.open(settingsUrl)
                }
            case .alertSecondButtonReturn:
                // Re-check permission immediately; users can switch back after toggling.
                continue
            default:
                return false
            }
        }
        return true
    }

    private func launchHeadless() {
        Logger.initialize()
        Logger.info { "Launching \(App.name) \(App.version)" }
        ensureGuiAltTabIsNotRunning()

        AXUIElement.setGlobalTimeout()
        Preferences.initialize()

        if !ensureAccessibilityPermission() {
            failFast("Accessibility permission is required for this app copy (\(Bundle.main.bundlePath)). Grant it in System Settings > Privacy & Security > Accessibility, then relaunch.")
        }

        BackgroundWork.startHeadless()
        if !CliEvents.observe() {
            failFast(CliEvents.startupFailureMessage)
        }

        NSScreen.updatePreferred()
        Spaces.refresh()
        Screens.refresh()

        Applications.initialDiscovery()
        Applications.manuallyRefreshAllWindows()
        markReadyAfterInitialDiscovery()

        Logger.info { "Headless daemon is running" }
    }
}

extension App: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        launchHeadless()
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true
        return .terminateNow
    }
}
