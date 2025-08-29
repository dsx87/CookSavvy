//
//  DBInterfaceProtocol.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/08/2025.
//

protocol DBInterfaceProtocol {
    func getIngredients(byName name:String) throws -> [Ingredient]
    func getRecipes(byIngredients: [Ingredient]) throws -> [Recipe]
    
    func insertIngredients(_ ingredients: [Ingredient]) throws
    func insertRecipes(_ recipes: [Recipe]) throws
}

final class DBInterfaceClass: DBInterfaceProtocol {
    func getIngredients(byName name: String) throws -> [Ingredient] {
        []
    }
    
    func getRecipes(byIngredients: [Ingredient]) throws -> [Recipe] {
        []
    }
    
    func insertIngredients(_ ingredients: [Ingredient]) throws {
        
    }
    
    func insertRecipes(_ recipes: [Recipe]) throws {
        
    }
    
    
}
