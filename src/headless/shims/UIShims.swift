import Cocoa

enum RefreshCausedBy {
    case showUi
    case refreshOnlyThumbnailsAfterShowUi
    case refreshUiAfterThumbnailsHaveBeenRefreshed
    case refreshUiAfterExternalEvent
}

enum CALayerContents {
    case cgImage(CGImage?)
    case pixelBuffer(CVPixelBuffer?)

    func size() -> NSSize? {
        switch self {
        case .cgImage(let image):
            return image?.size()
        case .pixelBuffer(let pixelBuffer):
            return pixelBuffer?.size()
        }
    }
}

final class DummyThumbnailImageView {
    var isHidden = true
    var frame = NSRect.zero

    func updateContents(_ contents: CALayerContents?, _ size: NSSize) {
        frame.size = size
        isHidden = false
    }

    func releaseImage() {}
}

final class DummyDockLabelIcon {
    var isHidden = true
}

class ThumbnailView: NSView {
    var window_: Window?
    let thumbnail = DummyThumbnailImageView()
    let dockLabelIcon = DummyDockLabelIcon()

    func updateDockLabelIcon(_ label: String) {
        dockLabelIcon.isHidden = false
    }

    static func thumbnailSize(_ imageSize: NSSize?, _ isWindowlessApp: Bool) -> NSSize {
        imageSize ?? .zero
    }
}

class ThumbnailsView {
    static var recycledViews = [ThumbnailView]()

    let scrollView = NSScrollView()

    func reset() {}

    func navigateUpOrDown(_ direction: Direction, allowWrap: Bool = true) {}

    static func highlight(_ index: Int) {}
}

class ThumbnailsPanel {
    let thumbnailsView = ThumbnailsView()
    var isKeyWindow = false
    var windowNumber = Int.zero

    static var maxPossibleThumbnailSize = NSSize(width: 1, height: 1)
    static var maxPossibleAppIconSize = NSSize(width: 64, height: 64)

    static func updateMaxPossibleThumbnailSize() {}

    static func updateMaxPossibleAppIconSize() {}

    static func maxThumbnailsWidth(_ screen: NSScreen? = nil) -> CGFloat {
        1
    }

    static func maxThumbnailsHeight(_ screen: NSScreen? = nil) -> CGFloat {
        1
    }

    func show() {}

    func updateContents() {}

    @discardableResult
    func makeFirstResponder(_ responder: Any?) -> Bool {
        true
    }

    func orderOut(_ sender: Any?) {}
}

class PreviewPanel {
    func show(_ id: CGWindowID, _ preview: CALayerContents, _ position: CGPoint, _ size: CGSize) {}

    func updateIfShowing(_ id: CGWindowID?, _ preview: CALayerContents, _ position: CGPoint, _ size: CGSize) {}

    func orderOut(_ sender: Any?) {}
}

final class LiquidGlassEffectView {
    static func canUsePrivateLiquidGlassLook() -> Bool {
        false
    }
}

enum Direction {
    case leading
    case trailing
    case up
    case down

    func step() -> Int {
        switch self {
        case .leading, .up:
            return 1
        case .trailing, .down:
            return -1
        }
    }
}
