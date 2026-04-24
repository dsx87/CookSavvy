import SwiftUI
import UIKit

/// Builds branded PNG share cards for recipes.
///
/// The generator owns only presentation concerns for the share image: it loads the recipe photo
/// through `ImageServiceProtocol`, falls back to deterministic artwork when that image is missing,
/// and renders a fixed 4:5 SwiftUI composition to PNG data.
@MainActor
protocol RecipeShareCardGenerating: AnyObject {
    func makeShareCard(for recipe: Recipe) async -> RecipeShareCard
}

@MainActor
final class RecipeShareCardGenerator: RecipeShareCardGenerating {
    private let imageService: ImageServiceProtocol
    private static let placeholderImageName = "recipe_placeholder"

    init(imageService: ImageServiceProtocol) {
        self.imageService = imageService
    }

    func makeShareCard(for recipe: Recipe) async -> RecipeShareCard {
        let image = await loadRecipeImage(for: recipe)
        let view = RecipeShareCardView(recipe: recipe, image: image ?? fallbackImage(for: recipe))
            .frame(width: UI.ShareCard.width, height: UI.ShareCard.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = UI.ShareCard.renderScale
        renderer.proposedSize = ProposedViewSize(width: UI.ShareCard.width, height: UI.ShareCard.height)

        let pngData = renderer.uiImage?.pngData() ?? fallbackPNGData(for: recipe)
        return RecipeShareCard(title: recipe.title, pngData: pngData)
    }

    /// Loads the same recipe image asset path used by `RecipeImage`/`AsyncImageDisk`.
    ///
    /// Remote and already-expanded paths are handled by `ImageServiceProtocol.loadImage(for:)`;
    /// local dataset recipe records store only the base image name, so they need the bundled
    /// food-image prefix and `.jpg` extension before falling back to artwork.
    private func loadRecipeImage(for recipe: Recipe) async -> UIImage? {
        if let image = try? await imageService.loadImage(for: recipe) {
            return image
        }

        guard !recipe.image.isEmpty, recipe.image != Self.placeholderImageName else {
            return nil
        }

        let diskImageName = UI.DiskImage.defaultPrefix + recipe.image + UI.DiskImage.defaultExtension
        return try? await imageService.loadImage(named: diskImageName)
    }

    /// Produces deterministic fallback art keyed by recipe title so missing images still share
    /// as polished branded cards rather than surfacing an error or blank asset.
    private func fallbackImage(for recipe: Recipe) -> UIImage {
        let colors = fallbackColors(for: recipe.title)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UI.ShareCard.fallbackImageScale
        let renderer = UIGraphicsImageRenderer(size: UI.ShareCard.fallbackImageSize, format: format)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: UI.ShareCard.fallbackImageSize)
            let cgContext = context.cgContext
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [colors.primary.cgColor, colors.secondary.cgColor] as CFArray,
                locations: [0, 1]
            ) else {
                colors.primary.setFill()
                cgContext.fill(rect)
                return
            }
            cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.minX, y: rect.minY),
                end: CGPoint(x: rect.maxX, y: rect.maxY),
                options: []
            )

            UIColor.white.withAlphaComponent(UI.ShareCard.fallbackCircleOpacity).setFill()
            cgContext.fillEllipse(in: CGRect(x: -80, y: -60, width: 260, height: 260))
            cgContext.fillEllipse(in: CGRect(x: rect.maxX - 180, y: rect.maxY - 220, width: 280, height: 280))

            let emoji = recipe.emoji ?? IngredientEmojiProvider.emoji(for: recipe.ingredients.first?.name ?? recipe.title)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: UI.ShareCard.fallbackEmojiSize),
                .foregroundColor: UIColor.white
            ]
            let size = emoji.size(withAttributes: attributes)
            emoji.draw(
                at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                withAttributes: attributes
            )
        }
    }

    private func fallbackPNGData(for recipe: Recipe) -> Data {
        fallbackImage(for: recipe).pngData() ?? Data()
    }

    private func fallbackColors(for title: String) -> (primary: UIColor, secondary: UIColor) {
        let palettes: [(UIColor, UIColor)] = [
            (UIColor(red: 0.10, green: 0.48, blue: 0.40, alpha: 1), UIColor(red: 0.96, green: 0.58, blue: 0.34, alpha: 1)),
            (UIColor(red: 0.75, green: 0.25, blue: 0.30, alpha: 1), UIColor(red: 0.98, green: 0.72, blue: 0.38, alpha: 1)),
            (UIColor(red: 0.24, green: 0.42, blue: 0.65, alpha: 1), UIColor(red: 0.50, green: 0.75, blue: 0.55, alpha: 1)),
            (UIColor(red: 0.42, green: 0.30, blue: 0.62, alpha: 1), UIColor(red: 0.95, green: 0.53, blue: 0.60, alpha: 1))
        ]
        let stableHash = title.unicodeScalars.reduce(UInt64(0)) { ($0 &* 31) &+ UInt64($1.value) }
        let index = Int(stableHash % UInt64(palettes.count))
        return palettes[index]
    }
}

private struct RecipeShareCardView: View {
    let recipe: Recipe
    let image: UIImage

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: UI.ShareCard.width, height: UI.ShareCard.height)
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(UI.ShareCard.topOverlayOpacity),
                    Color.black.opacity(UI.ShareCard.bottomOverlayOpacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: UI.ShareCard.contentSpacing) {
                Spacer()
                metadataRow
                Text(recipe.title)
                    .font(UI.ShareCard.titleFont)
                    .foregroundStyle(.white)
                    .lineLimit(UI.ShareCard.titleLineLimit)
                    .minimumScaleFactor(UI.ShareCard.titleMinimumScale)
                Text(Strings.ShareCard.brand)
                    .font(UI.ShareCard.brandFont)
                    .foregroundStyle(.white.opacity(UI.ShareCard.secondaryTextOpacity))
                    .textCase(.uppercase)
            }
            .padding(UI.ShareCard.contentPadding)
        }
        .background(Color.black)
    }

    private var metadataRow: some View {
        HStack(spacing: UI.ShareCard.metadataSpacing) {
            metadataPill(String(format: Strings.ShareCard.ingredientsCount, Int64(recipe.ingredients.count)))
            if let cookTime = recipe.additionalInfo.infos.first(where: { info in
                if case .time = info { return true }
                return false
            }) {
                metadataPill(cookTime.stringValue)
            }
        }
    }

    private func metadataPill(_ text: String) -> some View {
        Text(text)
            .font(UI.ShareCard.metadataFont)
            .foregroundStyle(.white)
            .padding(.horizontal, UI.ShareCard.metadataHorizontalPadding)
            .padding(.vertical, UI.ShareCard.metadataVerticalPadding)
            .background(.white.opacity(UI.ShareCard.metadataBackgroundOpacity), in: Capsule())
    }
}
