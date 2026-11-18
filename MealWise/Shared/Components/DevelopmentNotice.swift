import SwiftUI

struct DevelopmentNotice: View {
    var body: some View {
        Text("Development recipes and synthetic prices. Not verified for real shopping or allergy-safe use.")
            .font(.footnote)
            .foregroundStyle(DesignTokens.textPrimary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.selection, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview { DevelopmentNotice().padding() }
