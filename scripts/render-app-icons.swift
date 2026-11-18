// Run from the repository root with Swift; no external dependencies.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let root = URL(fileURLWithPath: "MealWise/Resources/Assets.xcassets/AppIcon.appiconset")
let variants: [(String, [CGFloat], [CGFloat])] = [
    ("AppIcon.png", [16/255,107/255,75/255], [240/255,245/255,239/255]),
    ("AppIcon-dark.png", [17/255,28/255,23/255], [140/255,213/255,172/255]),
    ("AppIcon-tinted.png", [0,0,0], [1,1,1])
]
for (name, background, foreground) in variants {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(colorSpace: colorSpace, components: background + [1])!)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    context.translateBy(x: 68, y: 956); context.scaleBy(x: 37, y: -37)
    context.setStrokeColor(CGColor(colorSpace: colorSpace, components: foreground + [1])!)
    context.setLineWidth(1.8); context.setLineCap(.round); context.setLineJoin(.round)
    // Exact existing IconLeaf.svg geometry, scaled into the app-icon safe area.
    context.move(to: CGPoint(x: 19, y: 4))
    context.addCurve(to: CGPoint(x: 5, y: 14), control1: CGPoint(x: 11, y: 4), control2: CGPoint(x: 5, y: 8))
    context.addCurve(to: CGPoint(x: 10, y: 19), control1: CGPoint(x: 5, y: 17), control2: CGPoint(x: 7, y: 19))
    context.addCurve(to: CGPoint(x: 19, y: 4), control1: CGPoint(x: 16, y: 19), control2: CGPoint(x: 19, y: 12))
    context.closePath(); context.strokePath()
    context.move(to: CGPoint(x: 5, y: 20))
    context.addCurve(to: CGPoint(x: 15, y: 9), control1: CGPoint(x: 7, y: 15), control2: CGPoint(x: 10, y: 12)); context.strokePath()
    let destination = CGImageDestinationCreateWithURL(root.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination))
}
