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
        Windows.refreshThumbnailsAsync(windowsToScreenshot, source, windowRemoved: windowRemoved)
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

    private func launchHeadless() {
        Logger.initialize()
        Logger.info { "Launching \(App.name) \(App.version)" }

        AXUIElement.setGlobalTimeout()
        Preferences.initialize()

        BackgroundWork.preStart()

        if AccessibilityPermission.update() != .granted {
            failFast("Accessibility permission is required. Grant it in System Settings > Privacy & Security > Accessibility, then relaunch.")
        }

        BackgroundWork.start()

        NSScreen.updatePreferred()
        Spaces.refresh()
        Screens.refresh()

        SpacesEvents.observe()
        ScreensEvents.observe()

        Applications.initialDiscovery()
        Applications.manuallyRefreshAllWindows()
        markReadyAfterInitialDiscovery()

        CliEvents.observe()
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
