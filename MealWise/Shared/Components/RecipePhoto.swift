import SwiftUI
import UIKit

struct RecipePhoto: View {
    enum Layout {
        case thumbnail
        case hero
    }

    let recipeID: String
    let layout: Layout

    var body: some View {
        Group {
            if let photo = UIImage(named: "RecipePhotos/\(recipeID)") {
                switch layout {
                case .thumbnail:
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .hero:
                    Color.clear
                        .aspectRatio(1.55, contentMode: .fit)
                        .overlay {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else if layout == .thumbnail {
                Image("IconPot")
                    .frame(width: 52, height: 52)
                    .background(DesignTokens.selection, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .accessibilityHidden(true)
    }
}
