//
//  CookSavvyTests.swift
//  CookSavvyTests
//
//  Created by Igor Pivnyk on 29/08/2025.
//

import XCTest
@testable import CookSavvy

final class DBInterfaceTests: XCTestCase {

    var dbInterface: DBInterfaceClass!
//    var mockRecipes: [Recipe] = []
    override func setUpWithError() throws {
        dbInterface = DBInterfaceClass()
    }

    override func tearDownWithError() throws {
        dbInterface = nil
//        mockRecipes.removeAll()
    }

    func testInsertionRecipes() throws {
        let mockRecipes = Recipe.mocks(count: 10)
        try dbInterface.insertRecipes(mockRecipes)
        let ingredients = mockRecipes.flatMap(\.ingredients)
        
        let result = try dbInterface.getRecipes(byIngredients: ingredients)
        XCTAssertEqual(mockRecipes, result)
    }

    func testInsertionIngredients() throws {
        let mockIngredients = Ingredient.mocks(count: 5)
        let names = mockIngredients.map(\.name)
        try dbInterface.insertIngredients(mockIngredients)
        let result = try names.map { name in
            let ingr = try dbInterface.getIngredients(byName: name)
            XCTAssertEqual(ingr.count, 1)
            return try XCTUnwrap(ingr.first)
        }
        XCTAssertEqual(mockIngredients, result)
    }
    
    func testGettingRecipes() throws {
        let mockRecipes = Recipe.mocks(count: 5)
        try dbInterface.insertRecipes(mockRecipes)
        let failableIngredients = [
            Ingredient(name: "Failable name 3"),
            Ingredient(name: "Failable name 2"),
            Ingredient(name: "Failable name 1"),
        ]
        let successfullIngredients = mockRecipes
            .flatMap(\.ingredients)
            .randomElements(count: 5)
        
        let failResult = try dbInterface.getRecipes(byIngredients: failableIngredients)
        XCTAssertTrue(failResult.isEmpty)
        
        let success = try dbInterface.getRecipes(byIngredients: successfullIngredients)
        XCTAssertFalse(success.isEmpty)
        XCTAssertTrue(mockRecipes.contains(success))
    }
    
    func testPerformanceIngredientsInsertion() throws {
        let ingredients = Ingredient.mocks(count: 5000)
        measure {
            try? dbInterface.insertIngredients(ingredients)
        }
    }

    func testPerformanceRecipesInsertion() throws {
        let recipes = Recipe.mocks(count: 5000)
        measure {
            try? dbInterface.insertRecipes(recipes)
        }
    }
}

extension Array {
    func randomElements(count: Int) -> [Element] {
        var res: [Element] = []
        for _ in 0..<count {
            guard let rand = self.randomElement() else { continue }
            
            res.append(rand)
        }
        return res
    }
}
