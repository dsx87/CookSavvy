import Foundation

/// Deterministic local substitution service backed by a curated JSON catalog.
///
/// The service caches the decoded catalog after the first read, then resolves missing ingredients
/// through canonical names and aliases. Matching prefers substitutes the user already has so the
/// caller can surface "use what you have" guidance before suggesting a purchase.
final class SubstitutionService: SubstitutionServiceProtocol {
    private let loader: any SubstitutionCatalogLoading
    private let logger: any LoggerProtocol

    private var cachedCatalog: [SubstitutionCatalogEntry]?

    init(
        loader: any SubstitutionCatalogLoading,
        logger: any LoggerProtocol
    ) {
        self.loader = loader
        self.logger = logger
    }

    convenience init(
        bundle: Bundle = .main,
        logger: any LoggerProtocol = LoggingService().makeLogger(category: .substitutionService)
    ) {
        self.init(
            loader: LocalSubstitutionCatalogLoader(bundle: bundle, logger: logger),
            logger: logger
        )
    }

    func suggestions(
        for missingIngredientNames: [String],
        recipeIngredients: [Ingredient],
        availableIngredients: [Ingredient]
    ) async throws -> [IngredientSubstitutionSuggestion] {
        guard !missingIngredientNames.isEmpty else { return [] }

        let catalog = try currentCatalog()
        let availableNames = availableIngredients.map(\.name)

        return missingIngredientNames.compactMap { missingIngredientName in
            suggestion(
                for: missingIngredientName,
                recipeIngredients: recipeIngredients,
                availableIngredientNames: availableNames,
                catalog: catalog
            )
        }
    }

    private func currentCatalog() throws -> [SubstitutionCatalogEntry] {
        if let cachedCatalog {
            return cachedCatalog
        }

        let catalog = try loader.loadCatalog()
        cachedCatalog = catalog
        logger.info("Loaded \(catalog.count) substitution catalog entries")
        return catalog
    }

    private func suggestion(
        for missingIngredientName: String,
        recipeIngredients: [Ingredient],
        availableIngredientNames: [String],
        catalog: [SubstitutionCatalogEntry]
    ) -> IngredientSubstitutionSuggestion? {
        guard let entry = entry(for: missingIngredientName, recipeIngredients: recipeIngredients, catalog: catalog) else {
            return nil
        }

        let options = entry.substitutes
            .map { option in
                IngredientSubstitutionOption(
                    ingredientName: option.ingredient,
                    ratio: option.ratio,
                    note: option.note,
                    isAvailableFromUserIngredients: isOptionAvailable(option, availableIngredientNames: availableIngredientNames)
                )
            }
            .sorted(by: optionSortOrder)

        guard !options.isEmpty else { return nil }
        return IngredientSubstitutionSuggestion(
            missingIngredientName: missingIngredientName,
            options: options
        )
    }

    private func entry(
        for missingIngredientName: String,
        recipeIngredients: [Ingredient],
        catalog: [SubstitutionCatalogEntry]
    ) -> SubstitutionCatalogEntry? {
        // The missing ingredient can be shorter than the original recipe ingredient name
        // (for example, "onion" vs "green onion"), so search across the missing name plus
        // any matching recipe ingredient variants before consulting aliases.
        let candidateNames = candidateNames(for: missingIngredientName, recipeIngredients: recipeIngredients)
        return catalog.first { entry in
            candidateNames.contains { candidateName in
                matches(candidateName, againstAnyOf: [entry.ingredient] + entry.aliases)
            }
        }
    }

    private func candidateNames(
        for missingIngredientName: String,
        recipeIngredients: [Ingredient]
    ) -> [String] {
        let normalizedMissing = RecipeMatchExplainer.normalizedIngredientName(missingIngredientName)
        var candidateNames = [missingIngredientName]
        for ingredient in recipeIngredients {
            let normalizedRecipeName = RecipeMatchExplainer.normalizedIngredientName(ingredient.name)
            guard !normalizedRecipeName.isEmpty else { continue }
            if normalizedRecipeName == normalizedMissing
                || normalizedRecipeName.contains(normalizedMissing)
                || normalizedMissing.contains(normalizedRecipeName) {
                candidateNames.append(ingredient.name)
            }
        }
        return uniqueNames(candidateNames)
    }

    private func isOptionAvailable(
        _ option: SubstitutionCatalogOption,
        availableIngredientNames: [String]
    ) -> Bool {
        let candidates = [option.ingredient] + option.aliases
        return availableIngredientNames.contains { availableName in
            matches(availableName, againstAnyOf: candidates)
        }
    }

    private func optionSortOrder(
        lhs: IngredientSubstitutionOption,
        rhs: IngredientSubstitutionOption
    ) -> Bool {
        if lhs.isAvailableFromUserIngredients != rhs.isAvailableFromUserIngredients {
            return lhs.isAvailableFromUserIngredients && !rhs.isAvailableFromUserIngredients
        }
        return lhs.ingredientName.localizedCaseInsensitiveCompare(rhs.ingredientName) == .orderedAscending
    }

    private func matches(_ candidateName: String, againstAnyOf names: [String]) -> Bool {
        let normalizedCandidate = RecipeMatchExplainer.normalizedIngredientName(candidateName)
        guard !normalizedCandidate.isEmpty else { return false }

        return names
            .map(RecipeMatchExplainer.normalizedIngredientName)
            .contains { normalizedName in
                !normalizedName.isEmpty && (
                    normalizedName == normalizedCandidate ||
                    normalizedName.contains(normalizedCandidate) ||
                    normalizedCandidate.contains(normalizedName)
                )
            }
    }

    private func uniqueNames(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { value in
            let normalized = RecipeMatchExplainer.normalizedIngredientName(value)
            guard !normalized.isEmpty else { return false }
            return seen.insert(normalized).inserted
        }
    }
}
