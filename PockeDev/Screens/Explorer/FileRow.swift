import SwiftUI

// MARK: - FileRow (COMPONENT_MAP: FileRow)
// DESIGN.md §5.2: User must scan 10 files in <2s — minimal icons, clear indentation.

struct FileRow: View {
    let item: FileItem
    let depth: Int
    let isActive: Bool
    let isSelecting: Bool
    let isSelected: Bool
    let action: () -> Void

    private var indentWidth: CGFloat { CGFloat(depth) * 16 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.sm) {
                // Depth indentation
                if depth > 0 {
                    Spacer().frame(width: indentWidth)
                }

                // Selection circle or file icon
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? Tokens.Color.accent : Tokens.Color.textSecondary)
                        .frame(width: 18)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                        .frame(width: 18)
                }

                // Name
                Text(item.name)
                    .font(.system(size: 14, weight: isActive ? .medium : .regular))
                    .foregroundColor(isActive ? Tokens.Color.accent : Tokens.Color.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Folder disclosure indicator (hidden in selection mode)
                if item.isDirectory && !isSelecting {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Tokens.Color.textSecondary.opacity(0.5))
                }
            }
            .frame(minHeight: 44)
            .padding(.horizontal, Tokens.Spacing.lg)
            .background(
                isSelected ? Tokens.Color.accent.opacity(0.15) :
                isActive   ? Tokens.Color.accent.opacity(0.08) :
                Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Icon

    private var iconName: String {
        if item.isDirectory { return "folder" }
        switch item.ext.lowercased() {
        case "swift":    return "swift"
        case "md":       return "doc.text"
        case "json":     return "curlybraces"
        case "txt":      return "doc.plaintext"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        default:         return "doc"
        }
    }

    private var iconColor: Color {
        if item.isDirectory { return Tokens.Color.warning }
        if isActive { return Tokens.Color.accent }
        return Tokens.Color.textSecondary
    }
}
