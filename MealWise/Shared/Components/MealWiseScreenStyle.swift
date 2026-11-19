import SwiftUI

extension View {
    /// Applies the app palette while keeping native list and form controls.
    func mealWiseListStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .mealWiseScreenStyle()
    }

    func mealWiseScreenStyle() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.surface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }

    func mealWiseListRows() -> some View {
        listRowBackground(DesignTokens.card)
    }
}

/// An overview at the top of a tab, using the same surface as Week's budget card.
struct MealWiseOverview<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignTokens.gold)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(DesignTokens.panel, in: RoundedRectangle(cornerRadius: 23))
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    List {
        Section {
            MealWiseOverview(icon: "basket") {
                Text("Additional estimated checkout").font(.subheadline)
                Text("$64.30").font(.largeTitle.bold())
            }
        }
    }
    .mealWiseListStyle()
}
