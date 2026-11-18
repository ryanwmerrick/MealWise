import SwiftUI

struct SetupBudgetPicker: View {
    @Binding var budget: String
    let minorUnits: Int64
    @State private var selectedAmount: Int?
    @State private var amountRange = 5...500
    @State private var isUserScrolling = false

    private let tickWidth: CGFloat = 13
    private static let maximumAmount = Int(Int64.max / 500) * 5

    private var roundedAmount: Int {
        let lowerTick = Int(minorUnits / 500) * 5
        let rounded = minorUnits % 500 >= 250 ? lowerTick + 5 : lowerTick
        return min(Self.maximumAmount, max(5, rounded))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(stride(from: amountRange.lowerBound, through: amountRange.upperBound, by: 5)), id: \.self) { amount in
                        Capsule()
                            .fill(DesignTokens.textSecondary.opacity(amount.isMultiple(of: 25) ? 0.64 : 0.38))
                            .frame(width: 2, height: amount.isMultiple(of: 25) ? 34 : 20)
                            .frame(width: tickWidth, height: 56)
                            .id(amount)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, max(0, (geometry.size.width - tickWidth) / 2), for: .scrollContent)
            .scrollIndicators(.hidden)
            .mask {
                LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18),
                            .init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                    startPoint: .leading, endPoint: .trailing
                )
                .allowsHitTesting(false)
            }
            .overlay {
                Capsule()
                    .fill(DesignTokens.action)
                    .frame(width: 3, height: 52)
                    .allowsHitTesting(false)
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            .scrollPosition(id: $selectedAmount, anchor: .center)
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { isUserScrolling = true }
                if phase == .idle {
                    if isUserScrolling, let selectedAmount { budget = String(selectedAmount) }
                    isUserScrolling = false
                }
            }
        }
        .frame(height: 56)
        .accessibilityRepresentation {
            Text("Weekly budget scale")
                .accessibilityValue(minorUnits.currency)
                .accessibilityIdentifier("setup.budget.scale")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        if roundedAmount < Self.maximumAmount { select(roundedAmount + 5) }
                    case .decrement:
                        if minorUnits > 500 { select(max(5, roundedAmount - 5)) }
                    @unknown default: break
                    }
                }
        }
        .onAppear { synchronizeScale() }
        .onChange(of: selectedAmount) { _, amount in
            if isUserScrolling, let amount { budget = String(amount) }
        }
        .onChange(of: minorUnits) { _, _ in
            if !isUserScrolling { synchronizeScale() }
        }
    }

    private func synchronizeScale() {
        if !amountRange.contains(roundedAmount) {
            if roundedAmount <= 500 {
                amountRange = 5...500
            } else {
                amountRange = (roundedAmount - 245)...min(Self.maximumAmount, roundedAmount + 250)
            }
        }
        if selectedAmount != roundedAmount { selectedAmount = roundedAmount }
    }

    private func select(_ amount: Int) {
        budget = String(amount)
    }
}
