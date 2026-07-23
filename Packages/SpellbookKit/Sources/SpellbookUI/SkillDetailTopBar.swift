import SwiftUI

struct SkillDetailTopBar<MoreMenu: View>: View {
    let skillName: String
    let horizontalInset: Double
    let showsManagementInspector: Bool
    let onToggleManagementInspector: () -> Void
    private let moreMenu: MoreMenu

    init(
        skillName: String,
        horizontalInset: Double,
        showsManagementInspector: Bool,
        onToggleManagementInspector: @escaping () -> Void,
        @ViewBuilder moreMenu: () -> MoreMenu
    ) {
        self.skillName = skillName
        self.horizontalInset = horizontalInset
        self.showsManagementInspector = showsManagementInspector
        self.onToggleManagementInspector = onToggleManagementInspector
        self.moreMenu = moreMenu()
    }

    var body: some View {
        HStack(spacing: SpellbookDesign.Space.xSmall) {
            Text(skillName)
                .font(SpellbookDesign.Typography.sectionTitle)
                .foregroundStyle(SpellbookDesign.Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("Fixed skill title")

            moreMenu

            Spacer(minLength: SpellbookDesign.Space.medium)

            SpellbookIconButton(
                icon: .disclosure,
                label: showsManagementInspector ? "Hide Manage" : "Show Manage",
                size: SpellbookIconUsage.denseChrome,
                frame: .compact,
                colorRole: .interactive,
                rotationDegrees: showsManagementInspector ? 0 : 180,
                action: onToggleManagementInspector
            )
            .accessibilityIdentifier("Toggle Manage Inspector")
        }
        .padding(.leading, horizontalInset)
        .padding(.trailing, SpellbookDesign.Space.large)
        .frame(minHeight: SpellbookDesign.Detail.fixedTitleBarHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Skill title bar")
    }
}

struct SkillDetailTopBarBackdrop: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(progressiveMask)
            .overlay(canvasFade)
            .frame(
                height: SpellbookDesign.Detail.fixedTitleBarHeight
                    + SpellbookDesign.Sidebar.scrollEdgeVeilHeight
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var progressiveMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black.opacity(0.58), location: 0.48),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var canvasFade: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: SpellbookDesign.Palette.canvas, location: 0),
                .init(color: SpellbookDesign.Palette.canvas.opacity(0.58), location: 0.48),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
