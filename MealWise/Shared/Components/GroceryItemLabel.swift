import SwiftUI

struct GroceryItemLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let name: String
    let packages: Int64
    let packageSize: String
    let costMinorUnits: Int64
    var showsActualPrice = false

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(name)).font(.subheadline.weight(.semibold))
                Text("\(packages) × \(packageSize)")
                    .font(.caption).foregroundStyle(DesignTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                Text(costMinorUnits.currency)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
                if showsActualPrice {
                    Text("Actual").font(.caption2).foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
        .foregroundStyle(DesignTokens.textPrimary)
        .padding(.vertical, 3)
    }
}

#Preview {
    GroceryItemLabel(name: "Bell pepper", packages: 1, packageSize: "500 g", costMinorUnits: 199)
        .padding()
}
