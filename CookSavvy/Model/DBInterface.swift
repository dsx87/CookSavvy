//
//  DBInterface.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 04/08/2025.
//

import Foundation

class DBInterface {
    private var recipees: [Recipe] = []
    private var ingredients: [Ingredient] = []
    
    func getRecipees(byName name: String) -> [Recipe] {
        if recipees.isEmpty { extractRecipes() }
        return recipees.filter({ $0.title.lowercased().contains(name.lowercased()) })
    }
    
    func getRecipees(byIngredients ingredients: [Ingredient]) -> [Recipe] {
        if recipees.isEmpty { extractRecipes() }
        
        let searchNames = ingredients.map(\.name)
        
        return recipees.filter { recipe in
            recipe.cleanedIngredients.contains { ingredient in
                searchNames.contains { searchName in
                    ingredient.name.contains(searchName)
                }
            }
        }
    }
    
    func getIngredients(byName name: String) -> [Ingredient] {
        if self.ingredients.isEmpty {
            extractIngredients()
        }
        let res = ingredients.filter({ $0.name.lowercased().contains(name.lowercased()) })
        return res
    }
    
    @discardableResult
    private func extractIngredients() -> [Ingredient] {
        let ingredientsFile = Bundle.main.url(forResource: "Food", withExtension: "json")
        guard let ingredientsFile else {
            debugPrint("No ingredients file")
            self.ingredients = []
            return []
        }
        
        do {
            let data = try Data(contentsOf: ingredientsFile)
            self.ingredients = try JSONDecoder().decode([Ingredient].self, from: data)
        } catch {
            self.ingredients = []
            debugPrint("Ingredinets parsing error - \(error)")
        }
        return ingredients
    }
    
    @discardableResult
    private func extractRecipes() -> [Recipe] {
        let csvConv = CSVToJSONReader()
        let zip = Bundle.main.url(forResource: "food-ingredients-and-recipe-dataset-with-images", withExtension: "zip")!
        let res:[Recipe] = try! csvConv.parseCSVFromZip(zipURL: zip,
                                                        csvFilename: "Food Ingredients and Recipe Dataset with Image Name Mapping.csv")
        self.recipees = res
        return res
    }
}
