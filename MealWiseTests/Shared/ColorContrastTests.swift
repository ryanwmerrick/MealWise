import Testing
import UIKit
@testable import MealWise

struct ColorContrastTests {
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func textRemainsReadable(style: UIUserInterfaceStyle) throws {
        let bundle = Bundle.main
        for (foreground, background) in [("TextPrimary", "WelcomeSurface"), ("TextSecondary", "WelcomeSurface"), ("ButtonText", "Brand"), ("Action", "Surface")] {
            let front = try #require(UIColor(named: foreground, in: bundle, compatibleWith: UITraitCollection(userInterfaceStyle: style)))
            let back = try #require(UIColor(named: background, in: bundle, compatibleWith: UITraitCollection(userInterfaceStyle: style)))
            let values = [front, back].map { color -> Double in
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                let linear = [red, green, blue].map { component -> Double in
                    let value = Double(component)
                    return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
                }
                return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
            }
            #expect((values.max()! + 0.05) / (values.min()! + 0.05) >= 4.5)
        }
    }
}
