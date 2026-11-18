import SwiftUI

/// The owner supplies validated progress and localized accessibility values.
struct UsageMeter: View {
    let progress: Double
    let label: LocalizedStringKey
    let value: Text

    var body: some View {
        ProgressView(value: min(max(progress.isFinite ? progress : 0, 0), 1))
            .tint(DesignTokens.gold)
            .accessibilityLabel(Text(label))
            .accessibilityValue(value)
    }
}

#Preview("Meter states") {
    VStack(spacing: 20) {
        UsageMeter(progress: 0, label: "Budget used", value: Text("None"))
        UsageMeter(progress: 0.918, label: "Budget used", value: Text("Almost all"))
        UsageMeter(progress: 1, label: "Budget used", value: Text("All"))
    }.padding().background(DesignTokens.panel)
}
