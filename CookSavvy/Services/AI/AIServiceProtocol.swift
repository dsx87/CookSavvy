//
//  AIServiceProtocol.swift
//  CookSavvy
//

import Foundation

protocol AIServiceProtocol {
    var isAvailable: Bool { get }
    func detectIngredients(from imageData: Data) async throws -> [Ingredient]
    func generateRecipes(for ingredients: [Ingredient], count: Int) async throws -> [Recipe]
}
