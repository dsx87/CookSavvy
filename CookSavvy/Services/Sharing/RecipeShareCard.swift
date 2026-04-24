import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// PNG payload exported by the system share sheet for visual recipe sharing.
///
/// The card remains separate from `Recipe` so the model can keep its existing plain-text
/// `shareText` representation while `ShareLink` uses this image as the primary shared item.
struct RecipeShareCard: Transferable, Equatable {
    let title: String
    let pngData: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            card.pngData
        }
    }
}
