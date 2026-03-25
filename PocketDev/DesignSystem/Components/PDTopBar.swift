import SwiftUI

// MARK: - TopBar (COMPONENT_MAP: TopBar)
// Information hierarchy: Context (project/file) always visible (DESIGN.md §2.1)
// Touch targets ≥ 44pt (DESIGN.md §9)

struct PDTopBar<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let leadingIcon: String?
    let leadingAction: (() -> Void)?
    let trailing: Trailing

    // Full init with explicit trailing view
    init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: String? = nil,
        leadingAction: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.leadingAction = leadingAction
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            if let leadingIcon, let leadingAction {
                Button(action: leadingAction) {
                    Image(systemName: leadingIcon)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Tokens.Color.accent)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Tokens.Color.textPrimary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Tokens.Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            trailing
        }
        .padding(.leading, leadingIcon != nil ? 0 : Tokens.Spacing.lg)
        .padding(.trailing, Tokens.Spacing.lg)
        .frame(height: 52)
        .background(Tokens.Color.surface)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Tokens.Color.panel),
            alignment: .bottom
        )
    }
}

// MARK: - Convenience: no trailing

extension PDTopBar where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: String? = nil,
        leadingAction: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            leadingIcon: leadingIcon,
            leadingAction: leadingAction,
            trailing: { EmptyView() }
        )
    }
}
