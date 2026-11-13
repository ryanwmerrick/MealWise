import SwiftUI

/// Decorative sample receipt copied from Make; it never participates in budget accounting.
struct WelcomeIllustration: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color("ArtGreen"), Color("ArtGold")], startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack {
                Circle().fill(Color("ProduceRed")).frame(width: 64, height: 64).offset(y: 62)
                Spacer()
                VStack {
                    Circle().fill(Color("ProduceGreen")).frame(width: 44, height: 44)
                    Spacer()
                    Circle().fill(Color("ProduceGold")).frame(width: 52, height: 52)
                }.padding(.vertical, 22)
            }.padding(.horizontal, 25)
            receipt
                .frame(width: 226)
                .rotationEffect(.degrees(-3))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 12)
        }
        .frame(height: 250)
        .clipped()
        .accessibilityHidden(true)
        .environment(\.dynamicTypeSize, .medium)
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THIS WEEK").font(.system(.caption2, design: .monospaced)).tracking(1)
            Text("$64.30").font(.system(size: 36, weight: .bold))
            Text("of your $70 budget").font(.caption)
            ProgressView(value: 0.918).tint(Color("ReceiptGreen")).padding(.vertical, 6)
            HStack {
                Text("5 dinners")
                Spacer()
                Text("$5.70 left").bold().foregroundStyle(Color("ReceiptGreen"))
            }.font(.caption2)
        }
        .foregroundStyle(Color("ReceiptText"))
        .padding(19)
        .padding(.bottom, 12)
        .background(Color("ReceiptPaper"))
        .clipShape(ReceiptShape())
    }
}

private struct ReceiptShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: rect.maxX, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.height * 0.95))
            for index in 1...25 {
                path.addLine(to: CGPoint(x: rect.width * (1 - CGFloat(index) / 25),
                                        y: rect.height * (index.isMultiple(of: 2) ? 0.95 : 1)))
            }
            path.closeSubpath()
        }
    }
}

#Preview { WelcomeIllustration() }
