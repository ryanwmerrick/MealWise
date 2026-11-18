import SwiftUI

struct DevelopmentNotice: View {
    var body: some View {
        Text("Sample prices. Allergen information is unverified.")
            .font(.footnote)
            .foregroundStyle(DesignTokens.textSecondary)
    }
}

#Preview { DevelopmentNotice().padding() }
