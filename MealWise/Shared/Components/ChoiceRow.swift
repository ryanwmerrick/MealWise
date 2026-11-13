import SwiftUI

struct ChoiceRow: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(DesignTokens.textPrimary)
                Spacer(minLength: 12)
                ZStack {
                    Circle().fill(isSelected ? DesignTokens.brand : .clear)
                    Circle().stroke(isSelected ? DesignTokens.brand : DesignTokens.border)
                    if isSelected {
                        Image("IconCheck").foregroundStyle(DesignTokens.buttonText)
                    }
                }
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            }
            .font(.body)
            .padding(16)
            .frame(minHeight: 58)
            .background(isSelected ? DesignTokens.selection : DesignTokens.card,
                        in: RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.cardRadius)
                    .stroke(isSelected ? DesignTokens.action : DesignTokens.border)
            }
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Selection states") {
    VStack {
        ChoiceRow(title: "Dinner", isSelected: true) {}
        ChoiceRow(title: "Lunch", isSelected: false) {}
    }.padding().background(DesignTokens.surface)
}
