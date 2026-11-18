import SwiftUI

extension PlanningGoal {
    var label: String {
        switch self {
        case .saveMoney: "Save money"
        case .eatHealthier: "Eat healthier"
        case .findRecipes: "Find new recipes"
        case .saveTime: "Spend less time cooking"
        case .wasteLess: "Waste less food"
        }
    }

    var symbol: String {
        switch self {
        case .saveMoney: "dollarsign.circle"
        case .eatHealthier: "leaf"
        case .findRecipes: "book"
        case .saveTime: "clock"
        case .wasteLess: "arrow.3.trianglepath"
        }
    }
}

extension CookingStyle {
    var label: String {
        switch self {
        case .quickAndEasy: "Quick and easy"
        case .onePan: "One pan"
        case .familyFavorites: "Family favorites"
        case .classics: "Classics"
        }
    }
}

extension GroceryPreference {
    var label: String {
        switch self {
        case .aldi: "ALDI"
        case .walmart: "Walmart"
        case .target: "Target"
        case .costco: "Costco"
        case .kroger: "Kroger"
        case .traderJoes: "Trader Joe’s"
        case .wholeFoods: "Whole Foods"
        case .publix: "Publix"
        case .lidl: "Lidl"
        case .other: "Other store"
        }
    }

    var logoAsset: String? {
        self == .other ? nil : "store-\(rawValue)"
    }
}

struct SetupChoice: View {
    let title: LocalizedStringKey
    let icon: String?
    let selected: Bool
    let action: () -> Void

    init(_ title: LocalizedStringKey, icon: String? = nil, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.selected = selected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(DesignTokens.action)
                        .accessibilityHidden(true)
                }
                Text(title).font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? DesignTokens.action : DesignTokens.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(minHeight: 52)
            .background(DesignTokens.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? DesignTokens.action : DesignTokens.textSecondary.opacity(0.2))
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SetupFoodRain: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let foods = ["🍅", "🥕", "🥦", "🍋", "🥑", "🫑", "🌽", "🍓", "🍄", "🥬", "🍆", "🧅", "🥔", "🍌", "🍊", "🥒"]
    @State private var start = Date.now

    var body: some View {
        Group {
            if reduceMotion {
                field(elapsed: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { frame in
                    field(elapsed: max(0, frame.date.timeIntervalSince(start)))
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func field(elapsed: TimeInterval) -> some View {
        Canvas { context, size in
            for index in foods.indices {
                let column = index % 5
                let row = index / 5
                let offset = Double((index * 7) % 13) / 13
                let x = size.width * (Double(column) + 0.2 + 0.6 * offset) / 5
                let speed = 0.17 + Double(column % 3) * 0.04
                let phase = (Double(row) * 0.29 + offset * 0.14 + elapsed * speed)
                    .truncatingRemainder(dividingBy: 1)
                let y = phase * (size.height + 100) - 50
                let food = Text(foods[index]).font(.system(size: 27 + Double(index % 4) * 6))
                context.draw(food, at: CGPoint(x: x, y: y))
            }
        }
        .opacity(0.76)
    }
}
