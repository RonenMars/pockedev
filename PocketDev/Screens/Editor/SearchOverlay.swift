import SwiftUI

// MARK: - SearchOverlay (COMPONENT_MAP: SearchOverlay)
// In-file search only. No replace. No persistence.
// DESIGN.md §3.1: overlay for transient tools.
// DESIGN.md §6.3: fade + slight elevation transition (handled by caller).

struct SearchOverlay: View {
    @Binding var query: String
    let matchCount: Int
    let currentIndex: Int       // 0-based; -1 = no matches
    var onNext: () -> Void
    var onPrevious: () -> Void
    var onDismiss: () -> Void

    @FocusState private var fieldFocused: Bool

    // MARK: - Computed labels

    private var matchLabel: String {
        guard !query.isEmpty else { return "" }
        if matchCount == 0 { return "No results" }
        return "\(currentIndex + 1) of \(matchCount)"
    }

    private var hasMatches: Bool { matchCount > 0 }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            searchField

            Divider()
                .frame(height: 20)
                .background(Tokens.Color.panel)

            navButton(icon: "chevron.up", enabled: hasMatches, action: onPrevious)
            navButton(icon: "chevron.down", enabled: hasMatches, action: onNext)

            Divider()
                .frame(height: 20)
                .background(Tokens.Color.panel)

            Button("Done", action: onDismiss)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Tokens.Color.accent)
                .frame(height: 44)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.Spacing.md)
        .frame(height: 48)
        .background(Tokens.Color.panel)
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
        .onAppear { fieldFocused = true }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(Tokens.Color.textSecondary)

            TextField("Find in file…", text: $query)
                .font(.system(size: 14))
                .foregroundColor(Tokens.Color.textPrimary)
                .tint(Tokens.Color.accent)
                .focused($fieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { onNext() }

            if !query.isEmpty {
                // Match counter
                Text(matchLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(matchCount == 0 ? Tokens.Color.error : Tokens.Color.textSecondary)
                    .fixedSize()
                    .transition(.opacity)

                // Clear
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Tokens.Color.textSecondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: Tokens.Motion.micro), value: query.isEmpty)
    }

    // MARK: - Nav buttons (prev / next)

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
