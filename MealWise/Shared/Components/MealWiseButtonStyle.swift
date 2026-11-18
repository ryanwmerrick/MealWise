import SwiftUI

struct MealWiseButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.controlHeight)
            .foregroundStyle(kind == .primary ? DesignTokens.buttonText : DesignTokens.action)
            .background(kind == .primary ? DesignTokens.brand : DesignTokens.card,
                        in: RoundedRectangle(cornerRadius: DesignTokens.buttonRadius))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: DesignTokens.buttonRadius)
                        .stroke(DesignTokens.border, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.buttonRadius))
    }
}

#Preview("Button states") {
    VStack {
        Button("Continue") {}.buttonStyle(MealWiseButtonStyle())
        Button("Continue") {}.buttonStyle(MealWiseButtonStyle()).disabled(true)
        Button("Go back") {}.buttonStyle(MealWiseButtonStyle(kind: .secondary))
    }.padding().background(DesignTokens.surface)
}
