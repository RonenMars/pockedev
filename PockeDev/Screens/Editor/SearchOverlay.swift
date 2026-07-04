import SwiftUI

// MARK: - SearchOverlay (COMPONENT_MAP: SearchOverlay)
// In-file find & replace. Regex + case toggles. No persistence.
// DESIGN.md §3.1: overlay for transient tools.

struct SearchOverlay: View {
    @Binding var query: String
    @Binding var replaceText: String
    @Binding var isRegex: Bool
    @Binding var isCaseSensitive: Bool
    @Binding var showReplace: Bool

    let matchCount: Int
    let currentIndex: Int       // 0-based; -1 = no matches
    let isInvalidRegex: Bool

    var onNext: () -> Void
    var onPrevious: () -> Void
    var onReplace: () -> Void
    var onReplaceAll: () -> Void
    var onDismiss: () -> Void

    @FocusState private var findFocused: Bool

    private var hasMatches: Bool { matchCount > 0 }

    private var matchLabel: String {
        guard !query.isEmpty else { return "" }
        if isInvalidRegex { return "Invalid regex" }
        if matchCount == 0 { return "No results" }
        return "\(currentIndex + 1) of \(matchCount)"
    }

    private var matchLabelColor: Color {
        (isInvalidRegex || matchCount == 0) ? Tokens.Color.error : Tokens.Color.textSecondary
    }

    var body: some View {
        VStack(spacing: 0) {
            findRow
            if showReplace {
                Divider().background(Tokens.Color.background)
                replaceRow
            }
        }
        .background(Tokens.Color.panel)
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
        .onAppear { findFocused = true }
        .animation(.easeInOut(duration: Tokens.Motion.micro), value: showReplace)
    }

    // MARK: - Find row

    private var findRow: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            Button {
                showReplace.toggle()
            } label: {
                Image(systemName: showReplace ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Tokens.Color.textSecondary)
                    .frame(width: 24, height: 44)
            }
            .buttonStyle(.plain)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(Tokens.Color.textSecondary)

            TextField("Find in file…", text: $query)
                .font(.system(size: 14))
                .foregroundColor(Tokens.Color.textPrimary)
                .tint(Tokens.Color.accent)
                .focused($findFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { onNext() }

            if !query.isEmpty {
                Text(matchLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(matchLabelColor)
                    .fixedSize()
            }

            toggle(label: ".*", isOn: $isRegex)
            toggle(label: "Aa", isOn: $isCaseSensitive)

            Divider().frame(height: 20).background(Tokens.Color.background)

            navButton(icon: "chevron.up", enabled: hasMatches, action: onPrevious)
            navButton(icon: "chevron.down", enabled: hasMatches, action: onNext)

            Button("Done", action: onDismiss)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Tokens.Color.accent)
                .frame(height: 44)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.Spacing.md)
        .frame(height: 48)
    }

    // MARK: - Replace row

    private var replaceRow: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: "arrow.2.squarepath")
                .font(.system(size: 13))
                .foregroundColor(Tokens.Color.textSecondary)
                .frame(width: 24)

            TextField(isRegex ? "Replace ($1, $2…)" : "Replace…", text: $replaceText)
                .font(.system(size: 14))
                .foregroundColor(Tokens.Color.textPrimary)
                .tint(Tokens.Color.accent)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button("Replace", action: onReplace)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(hasMatches ? Tokens.Color.accent : Tokens.Color.textSecondary.opacity(0.4))
                .buttonStyle(.plain)
                .disabled(!hasMatches)

            Button("All", action: onReplaceAll)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(hasMatches ? Tokens.Color.accent : Tokens.Color.textSecondary.opacity(0.4))
                .buttonStyle(.plain)
                .disabled(!hasMatches)
        }
        .padding(.horizontal, Tokens.Spacing.md)
        .frame(height: 48)
    }

    // MARK: - Option toggle

    private func toggle(label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(isOn.wrappedValue ? Tokens.Color.accent : Tokens.Color.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.small)
                        .fill(isOn.wrappedValue ? Tokens.Color.accent.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Nav buttons

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(enabled ? Tokens.Color.textPrimary : Tokens.Color.textSecondary.opacity(0.4))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
