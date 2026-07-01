import SwiftUI

// MARK: - Surface (COMPONENT_MAP: Surface)
// Layered background: background < surface < panel (DESIGN.md §4.1)

struct PDSurface<Content: View>: View {
    var color: Color = Tokens.Color.surface
    var cornerRadius: CGFloat = Tokens.Radius.medium
    var padding: CGFloat = 0
    let content: Content

    init(
        color: Color = Tokens.Color.surface,
        cornerRadius: CGFloat = Tokens.Radius.medium,
        padding: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.color = color
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(color)
            .cornerRadius(cornerRadius)
    }
}
