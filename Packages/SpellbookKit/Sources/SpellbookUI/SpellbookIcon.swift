import AppKit
import SwiftUI

enum SpellbookIcon: String, CaseIterable, Sendable {
    case search
    case clear = "xmark-circle-solid"
    case disclosure = "nav-arrow-right"
    case check
    case checkCircle = "check-circle"
    case badgeCheck = "badge-check"
    case unchecked = "square"
    case checked = "check-square-solid"
    case refresh
    case refreshDouble = "refresh-double"
    case downloadCircle = "download-circle"
    case submitDocument = "submit-document"
    case upload
    case undo
    case book
    case bookStack = "book-stack"
    case page
    case copy
    case archive
    case folder
    case folderPlus = "folder-plus"
    case packageBox = "package"
    case more = "more-horiz"
    case settings
    case palette
    case cpu
    case filterList = "filter-list"
    case columns = "view-columns-3"
    case sidebarExpand = "sidebar-expand"
    case sidebarCollapse = "sidebar-collapse"
    case link
    case linkSlash = "link-slash"
    case serverConnection = "server-connection"
    case network
    case combine
    case horizontalSplit = "horizontal-split"
    case warningCircle = "warning-circle"
    case warningTriangle = "warning-triangle"
    case helpCircle = "help-circle"
    case edit = "edit-pencil"
    case image = "media-image"
    case imageUnavailable = "media-image-xmark"
    case quote
    case minusCircle = "minus-circle"
    case trash
    case tools

    var assetName: String {
        "icon-\(rawValue)"
    }

    var isSolid: Bool {
        switch self {
        case .clear, .checked:
            true
        default:
            false
        }
    }

    var bundledImage: NSImage? {
        if let catalogImage = Bundle.module.image(forResource: assetName) {
            let image = catalogImage.copy() as? NSImage
            image?.isTemplate = true
            return image
        }
        let url = Bundle.module.resourceURL?
            .appending(path: "Icons.xcassets")
            .appending(path: "\(assetName).imageset")
            .appending(path: "\(assetName).svg")
        guard let url, let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }
}

enum SpellbookIconSize: Double, CaseIterable, Sendable {
    case micro = 10
    case compact = 12
    case small = 14
    case standard = 16
    case large = 20

    var points: Double { rawValue }
}

/// Optical recipes keep dense chrome smaller than content imagery while retaining
/// the same four physical size tokens.
enum SpellbookIconUsage {
    static let denseChrome: SpellbookIconSize = .micro
    static let standardControl: SpellbookIconSize = .small
    static let content: SpellbookIconSize = .standard
    static let emphasized: SpellbookIconSize = .large
}

enum SpellbookIconColorRole: Sendable {
    case primary
    case secondary
    case interactive
    case disabled
    case success
    case warning
    case error
    case update

    var color: Color {
        switch self {
        case .primary:
            SpellbookDesign.Palette.textPrimary
        case .secondary:
            SpellbookDesign.Palette.textSecondary
        case .interactive:
            SpellbookDesign.Palette.interaction
        case .disabled:
            SpellbookDesign.Palette.disabled
        case .success:
            SpellbookDesign.Palette.success
        case .warning:
            SpellbookDesign.Palette.warning
        case .error:
            SpellbookDesign.Palette.error
        case .update:
            SpellbookDesign.Palette.update
        }
    }
}

struct SpellbookIconView: View {
    let icon: SpellbookIcon
    var size: SpellbookIconSize = .standard
    var colorRole: SpellbookIconColorRole = .secondary

    var body: some View {
        Group {
            if let image = icon.bundledImage {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            }
        }
        .foregroundStyle(colorRole.color)
        .frame(width: size.points, height: size.points)
        .accessibilityHidden(true)
    }
}

struct SpellbookIconLabel: View {
    @Environment(\.isEnabled) private var isEnabled

    let title: String
    let icon: SpellbookIcon
    var size: SpellbookIconSize = .small
    var colorRole: SpellbookIconColorRole = .secondary

    var body: some View {
        Label {
            Text(title)
        } icon: {
            SpellbookIconView(
                icon: icon,
                size: size,
                colorRole: isEnabled ? colorRole : .disabled
            )
        }
    }
}

enum SpellbookIconButtonFrame: Double, CaseIterable, Sendable {
    case compact = 24
    case standard = 28
    case prominent = 32

    var points: Double { rawValue }
}

struct SpellbookIconButton: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    let icon: SpellbookIcon
    let label: String
    var size: SpellbookIconSize = .standard
    var frame: SpellbookIconButtonFrame = .standard
    var colorRole: SpellbookIconColorRole = .interactive
    var rotationDegrees = 0.0
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            SpellbookIconView(
                icon: icon,
                size: size,
                colorRole: isEnabled ? colorRole : .disabled
            )
            .rotationEffect(.degrees(rotationDegrees))
            .frame(width: frame.points, height: frame.points)
            .contentShape(.rect)
        }
        .buttonStyle(QuietIconButtonStyle(isHovering: isHovering))
        .spellbookFocusSurface(role: .control)
        .onHover { isHovering = isEnabled && $0 }
        .animation(SpellbookMotion.sidebarHover(reduceMotion: reduceMotion), value: isHovering)
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct QuietIconButtonStyle: ButtonStyle {
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: SpellbookDesign.Radius.small)
                    .fill(surfaceColor(isPressed: configuration.isPressed))
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }

    private func surfaceColor(isPressed: Bool) -> Color {
        if isPressed {
            SpellbookDesign.Palette.selection
        } else if isHovering {
            SpellbookDesign.Palette.hover
        } else {
            .clear
        }
    }
}
