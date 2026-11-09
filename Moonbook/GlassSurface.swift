import SwiftUI

/// Liquid Glass belongs to the control layer; book pages keep an opaque background.
private struct GlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(uiColor: .secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: radius))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
        }
    }
}

extension View {
    func moonbookGlass(radius: CGFloat = 26) -> some View {
        modifier(GlassSurface(radius: radius))
    }

    @ViewBuilder
    func moonbookPrimaryButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}
