import AppKit
import SwiftUI

struct WindowToolbarStyleConfigurator: NSViewRepresentable {
    let toolbarStyle: NSWindow.ToolbarStyle

    func makeNSView(context: Context) -> WindowToolbarStyleView {
        WindowToolbarStyleView(toolbarStyle: toolbarStyle)
    }

    func updateNSView(_ nsView: WindowToolbarStyleView, context: Context) {
        nsView.toolbarStyle = toolbarStyle
        nsView.window?.toolbarStyle = toolbarStyle
    }
}
