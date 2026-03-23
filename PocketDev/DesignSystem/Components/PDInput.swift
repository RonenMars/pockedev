import SwiftUI

// MARK: - Input (COMPONENT_MAP: Input)
// Persistent label, clear focus state (DESIGN.md §5.5)

struct PDInput: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Tokens.Color.textSecondary)
                .tracking(0.8)
                .textCase(.uppercase)

            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundColor(Tokens.Color.textPrimary)
                .tint(Tokens.Color.accent)
                .padding(Tokens.Spacing.md)
                .background(Tokens.Color.panel)
                .cornerRadius(Tokens.Radius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.small)
                        .stroke(
                            isFocused ? Tokens.Color.accent : Color.clear,
                            lineWidth: 1.5
                        )
                )
                .animation(.easeInOut(duration: Tokens.Motion.micro), value: isFocused)
        }
    }
}
