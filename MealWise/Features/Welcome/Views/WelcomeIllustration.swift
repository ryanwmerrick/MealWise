import SwiftUI

struct WelcomeIllustration: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color("ArtGreen"), Color("ArtGold")], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1).frame(width: 290)
            Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1).frame(width: 235)
            bill.rotationEffect(.degrees(-16)).offset(x: -60, y: -39)
            menu.rotationEffect(.degrees(9)).offset(x: 27, y: 0)
            ingredient("🍅", size: 58, angle: -12).offset(x: -95, y: 60)
            ingredient("🥬", size: 68, angle: 17).offset(x: 106, y: -51)
            ingredient("🥕", size: 65, angle: 15).offset(x: 119, y: 58)
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 41))
                .foregroundStyle(Color("ReceiptGreen"), Color("ReceiptPaper"))
                .rotationEffect(.degrees(-18))
                .offset(x: -110, y: -60)
        }
        .frame(height: 255)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, DesignTokens.inset)
        .accessibilityHidden(true)
        .environment(\.dynamicTypeSize, .medium)
    }

    private var bill: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color("ReceiptGreen"))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.55), lineWidth: 1).padding(7)
            }
            .frame(width: 137, height: 78)
            .shadow(color: .black.opacity(0.15), radius: 7, y: 5)
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("WEEKLY MENU").font(.system(.caption2, design: .monospaced).bold())
                .tracking(1)
            Divider()
            Label("Pasta night", systemImage: "fork.knife")
            Label("Veggie bowls", systemImage: "leaf")
            Label("Taco Tuesday", systemImage: "flame")
            Divider()
            Label("Groceries", systemImage: "checkmark.circle.fill")
                .fontWeight(.semibold).foregroundStyle(Color("ReceiptGreen"))
        }
        .font(.caption)
        .foregroundStyle(Color("ReceiptText"))
        .padding(15)
        .frame(width: 148)
        .background(Color("ReceiptPaper"), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 1, y: 8)
    }

    private func ingredient(_ symbol: String, size: CGFloat, angle: Double) -> some View {
        Text(symbol).font(.system(size: size)).rotationEffect(.degrees(angle))
            .shadow(color: .black.opacity(0.17), radius: 6, y: 5)
    }
}

#Preview { WelcomeIllustration() }
