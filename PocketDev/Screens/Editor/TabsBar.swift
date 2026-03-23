import SwiftUI

// MARK: - TabsBar (COMPONENT_MAP: TabsBar)
// Horizontal scroll, no wrapping.
// Tab states: active, inactive, dirty. Touch target ≥ 44pt.
// DESIGN.md §5.1: visible active state, close only on active.

struct TabsBar: View {
    let sessions: [DocumentSession]
    let activeID: UUID?
    var onActivate: (UUID) -> Void
    var onClose: (UUID) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(sessions) { session in
                        TabCell(
                            session: session,
                            isActive: session.id == activeID,
                            onActivate: { onActivate(session.id) },
                            onClose:   { onClose(session.id) }
                        )
                        .id(session.id)
                    }
                }
            }
            .onChange(of: activeID) { newID in
                guard let newID else { return }
                withAnimation(.easeInOut(duration: Tokens.Motion.micro)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
        .frame(height: 44)
        .background(Tokens.Color.surface)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Tokens.Color.panel),
            alignment: .bottom
        )
    }
}

// MARK: - TabCell

private struct TabCell: View {
    let session: DocumentSession
    let isActive: Bool
    let onActivate: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: Tokens.Spacing.sm) {
                // Dirty indicator (dot before name)
                if session.isDirty {
                    Circle()
                        .fill(Tokens.Color.warning)
                        .frame(width: 6, height: 6)
                }

                Text(session.fileName)
                    .font(.system(size: 13, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? Tokens.Color.textPrimary : Tokens.Color.textSecondary)
                    .lineLimit(1)

                // Close — only on active tab
                if isActive {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Tokens.Color.textSecondary)
                            .frame(width: 16, height: 16)
                            .background(Tokens.Color.panel)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Tokens.Spacing.md)
            .frame(height: 44)
            .background(
                isActive
                    ? Tokens.Color.background
                    : Color.clear
            )
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isActive ? Tokens.Color.accent : Color.clear),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}
