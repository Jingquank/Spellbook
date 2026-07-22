import AppKit

final class WindowToolbarStyleView: NSView {
    var toolbarStyle: NSWindow.ToolbarStyle

    init(toolbarStyle: NSWindow.ToolbarStyle) {
        self.toolbarStyle = toolbarStyle
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.toolbarStyle = toolbarStyle
    }
}
