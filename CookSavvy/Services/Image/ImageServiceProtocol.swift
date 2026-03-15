import Foundation
import UIKit

protocol ImageServiceProtocol: AnyObject {
    func loadImage(for recipe: Recipe) async throws -> UIImage?
    func loadImage(for ingredient: Ingredient) async throws -> UIImage?
    func loadImage(named fileName: String) async throws -> UIImage?
    func loadImages(for recipes: [Recipe]) async throws -> [String: UIImage]
    func prefetchImages(for recipes: [Recipe]) async
    func clearCache()
    func clearDiskCache(fileName: String?) throws
    func imageExists(named fileName: String) -> Bool
    var memoryCacheCount: Int { get }
}
