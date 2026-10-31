import SwiftUI

/// Separate search and history surfaces share one glass container in HistoryView.
struct ShelfSurface: ViewModifier {
    let cornerRadius: CGFloat
    var focused = false

    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.black.opacity(0.25)),
                             in: .rect(cornerRadius: cornerRadius))
                .overlay { rim }
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay { rim }
        }
    }

    private var rim: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
                LinearGradient(colors: [
                    .white.opacity(focused ? 0.32 : 0.2),
                    .white.opacity(0.07),
                    .white.opacity(0.12)
                ], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.75
            )
            .allowsHitTesting(false)
    }
}
