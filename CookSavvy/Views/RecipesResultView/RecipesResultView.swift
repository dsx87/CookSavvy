//
//  RecipesResultView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 03/07/2025.
//

import SwiftUI

@MainActor
final class RecipesResultViewModel: ObservableObject {
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var images: [String: UIImage] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private(set) var selectedIngredients: Set<Ingredient>

    private let recipeService: RecipeService
    private let imageService: ImageService
    private let dbInterface: DBInterfaceProtocol
    private let csvReader: CSVToJSONReader
    private let navigationPath: Binding<NavigationPath>

    init(
        selectedIngredients: Set<Ingredient>,
        navigationPath: Binding<NavigationPath>,
        recipeService: RecipeService,
        imageService: ImageService,
        dbInterface: DBInterfaceProtocol,
        csvReader: CSVToJSONReader
    ) {
        self.selectedIngredients = selectedIngredients
        self.navigationPath = navigationPath
        self.recipeService = recipeService
        self.imageService = imageService
        self.dbInterface = dbInterface
        self.csvReader = csvReader
    }

    func loadRecipes() async {
        guard !selectedIngredients.isEmpty else {
            recipes = []
            images = [:]
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            defer { isLoading = false }

            try await ensureRecipesImported()

            let lowercaseIngredients = normalizedIngredients()

            recipes = try await recipeService.getRecipes(for: lowercaseIngredients)
            images = try await imageService.loadImages(for: recipes)
        } catch {
            print("❌ Error loading recipes: \(error)")
            errorMessage = "Failed to load recipes: \(error.localizedDescription)"
            recipes = []
            images = [:]
        }
    }

    func getImage(for recipe: Recipe) -> UIImage? {
        images[recipe.id]
    }

    func handleRecipeSelection(_ recipe: Recipe) {
        navigationPath.wrappedValue.append(recipe)
    }

    func handleBack() {
        guard !navigationPath.wrappedValue.isEmpty else { return }
        navigationPath.wrappedValue.removeLast()
    }

    private func normalizedIngredients() -> [Ingredient] {
        selectedIngredients.map { ingredient in
            Ingredient(
                name: ingredient.name.lowercased(),
                description: ingredient.description,
                pictureFileName: ingredient.pictureFileName,
                foodGroup: ingredient.foodGroup,
                foodSubgroup: ingredient.foodSubgroup
            )
        }
    }

    private func ensureRecipesImported() async throws {
        let commonIngredients = try dbInterface.searchIngredients(matching: "a", limit: 1)

        print("🔍 Checking for existing recipes...")

        if !commonIngredients.isEmpty {
            let existingRecipes = try dbInterface.getRecipes(byIngredients: commonIngredients)

            if !existingRecipes.isEmpty {
                print("✅ Recipes already imported (\(existingRecipes.count) found)")
                return
            }
        }

        print("📥 Importing recipes from dataset...")

        guard let zipURL = Bundle.main.url(
            forResource: "food-ingredients-and-recipe-dataset-with-images",
            withExtension: "zip"
        ) else {
            throw NSError(
                domain: "RecipesResultViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Dataset ZIP file not found"]
            )
        }

        let importedRecipes: [Recipe] = try csvReader.parseCSVFromZip(
            zipURL: zipURL,
            csvFilename: "Food Ingredients and Recipe Dataset with Image Name Mapping.csv",
            useCache: true
        )

        print("📊 Parsed \(importedRecipes.count) recipes from CSV")

        try dbInterface.insertRecipes(importedRecipes)

        print("✅ Successfully imported \(importedRecipes.count) recipes to database")
    }
}

struct RecipesResultView: View {
    @StateObject private var viewModel: RecipesResultViewModel

    init(selectedIngredients: Set<Ingredient>, navigationPath: Binding<NavigationPath>) {
        let dbInterface = DBInterface()
        let recipeService = RecipeService(dbInterface: dbInterface)
        let imageService = ImageService()
        let csvReader = CSVToJSONReader()

        _viewModel = StateObject(
            wrappedValue: RecipesResultViewModel(
                selectedIngredients: selectedIngredients,
                navigationPath: navigationPath,
                recipeService: recipeService,
                imageService: imageService,
                dbInterface: dbInterface,
                csvReader: csvReader
            )
        )
    }

    init(viewModel: RecipesResultViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading recipes...")
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if viewModel.recipes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No recipes found")
                        .font(.headline)
                    Text("Try different ingredients")
                        .foregroundColor(.secondary)
                }
            } else {
                List(viewModel.recipes, id: \.id) { recipe in
                    RecipeResultCellView(
                        recipe: recipe,
                        image: viewModel.getImage(for: recipe)
                    )
                    .onTapGesture {
                        viewModel.handleRecipeSelection(recipe)
                    }
                }
                .listRowSpacing(18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(alignment: .leading) {
                    Text("Recipe search result")
                    SearchResultsHeader(count: viewModel.recipes.count, ingredients: viewModel.selectedIngredients)
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    viewModel.handleBack()
                }) {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .navigationDestination(for: Recipe.self) { recipe in
            RecipeDetailsView(recipe: recipe)
        }
        .task {
            await viewModel.loadRecipes()
        }
    }
}

#Preview("RecipesResultView") {
    RecipesResultView(
        selectedIngredients: ["Pasta, Basta, Something"],
        navigationPath: .constant(.init())
    )
}


struct RecipeResultCellView: View {
    let recipe: Recipe
    let image: UIImage?
    
    var body: some View {
        HStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .clipped()
            } else {
                DefaultPlaceholder()
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading) {
                Text(recipe.title)
                RecipeResultCellAdditionalInfoView(info: recipe.additionalInfo)
                RecipeResultCellIngredientsView(ingredients: recipe.ingredients)
            }
        }
    }
}

#Preview("RecipeResultCellView") {
    RecipeResultCellView(recipe: .init(), image: nil)
}


struct RecipeResultCellAdditionalInfoView: View {
    let info: Recipe.AdditionalInfo
    var body: some View {
        HStack {
            ForEach(info.infos, id: \.self) { info in
                VStack {
                    Text(info.asEmoji)
                    Text(info.stringValue)
                }
            }
        }
    }
}

#Preview("RecipeResultCellAdditionalInfoView") {
    RecipeResultCellAdditionalInfoView(info: .empty)
}


struct RecipeResultCellIngredientView: View {
    let name: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: .infinity)
                .foregroundStyle(Color.backOrange)
                .frame(maxWidth: .infinity, maxHeight: 20)
            Text(name)
                .font(.caption)
                
        }
    }
}

#Preview("RecipeResultCellIngredientsView") {
    RecipeResultCellIngredientView(name: "Ingredient")
}

struct RecipeResultCellIngredientsView: View {
    let ingredients: [Ingredient]
    var body: some View {
        HStack {
            ForEach(0..<(min(ingredients.count, 3)), id: \.self) { i in
                RecipeResultCellIngredientView(name: ingredients[i].name)
            }
        }
    }
}

#Preview {
    RecipeResultCellIngredientsView(ingredients: ["one", "two", "three"])
}
