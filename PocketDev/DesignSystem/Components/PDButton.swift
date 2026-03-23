import SwiftUI

// MARK: - Button (COMPONENT_MAP: Button)
// Rule: One primary action per screen (DESIGN.md §5.4)
// Touch target ≥ 44pt (DESIGN.md §9)

enum PDButtonVariant {
    case primary
    case secondary
    case ghost
}

struct PDButton: View {
    let title: String
    let variant: PDButtonVariant
    let action: () -> Void

    var icon: String? = nil
    var isDestructive: Bool = false
    var isLoading: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .tint(foregroundColor)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(minHeight: 44)
            .padding(.horizontal, Tokens.Spacing.lg)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(Tokens.Radius.small)
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.small)
                    .stroke(borderColor, lineWidth: variant == .secondary ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .animation(.easeInOut(duration: Tokens.Motion.micro), value: isLoading)
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:   return isDestructive ? Tokens.Color.error : Tokens.Color.accent
        case .secondary: return Color.clear
        case .ghost:     return Color.clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:   return isDestructive ? .white : Tokens.Color.background
        case .secondary: return isDestructive ? Tokens.Color.error : Tokens.Color.textPrimary
        case .ghost:     return Tokens.Color.textSecondary
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary: return isDestructive ? Tokens.Color.error.opacity(0.6) : Tokens.Color.panel
        default:         return Color.clear
        }
    }
}
