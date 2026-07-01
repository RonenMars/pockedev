import SwiftUI

// MARK: - EmptyState (COMPONENT_MAP: EmptyState)
// Rule: always include explanation + next action (DESIGN.md §7)

struct PDEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Tokens.Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundColor(Tokens.Color.textSecondary.opacity(0.6))

            VStack(spacing: Tokens.Spacing.sm) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Tokens.Color.textPrimary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(Tokens.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if let actionTitle, let action {
                PDButton(title: actionTitle, variant: .primary, action: action)
            }
        }
        .padding(Tokens.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}
