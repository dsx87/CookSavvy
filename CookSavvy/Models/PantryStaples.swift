import Foundation

/// Curated set of pantry staples — seasonings and basics assumed to be on hand in any kitchen.
///
/// Single source of truth for "this is not a real cooking ingredient the user picks a recipe
/// around". It drives two behaviours that must stay in lockstep:
/// 1. **Hidden from the ingredient picker** — `IngredientsService` / `UserDataService` filter these
///    out of catalogue browse, search, category chips, and the popular grid, so a user never selects
///    "salt" as if it were a substantive ingredient.
/// 2. **Auto-assumed during matching** — `RecipeMatchExplainer` treats these as already available, so
///    a recipe that needs salt is never penalised or shows salt as a "missing" ingredient.
///
/// The curated list lives in the bundled **`Seasonings.json`** resource (grouped by basics / oils /
/// dried spices for readability) rather than a code literal, so it can be tuned as data without
/// touching Swift — mirroring how `Substitutions.json` backs the substitution catalogue. The file is
/// loaded once, lazily, into `names`.
///
/// Scope is deliberately *narrow* (pantry staples only): salt, pepper, oils, water, sugar, vinegar,
/// and dried spices. Fresh herbs (basil, cilantro) and condiments/sauces (soy sauce, pesto, the
/// mustard *condiment*) are intentionally **excluded** so they remain selectable ingredients —
/// people genuinely build dishes around them. Note the distinction: `mustard seed` (a dried spice)
/// is a staple, while `mustard` (the sauce) is not.
///
/// Membership is **exact** after normalisation. Catalogue ingredient names are clean core nouns
/// ("salt", "cumin", "bell pepper"), so exact matching catches "pepper" while leaving "bell pepper"
/// selectable — the same safety `RecipeMatchExplainer` relied on with its prior hardcoded set.
///
/// `nonisolated` (not pinned to the main actor): a pure, stateless value utility, sibling to
/// `IngredientCategoryClassifier`.
nonisolated enum PantryStaples {

    /// `true` when `name` (after trim + lowercase) is a known pantry staple.
    static func isStaple(_ name: String) -> Bool {
        names.contains(normalize(name))
    }

    /// Returns `ingredients` with all pantry staples removed, preserving order.
    static func excludingStaples(_ ingredients: [Ingredient]) -> [Ingredient] {
        ingredients.filter { !isStaple($0.name) }
    }

    /// Normalised staple names, loaded once from the bundled `Seasonings.json` resource.
    static let names: Set<String> = loadNames()

    /// Trims and lowercases a name for consistent membership comparison.
    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Loading

    private enum Resource {
        static let fileName = "Seasonings"
        static let fileExtension = "json"
    }

    /// Reads and flattens `Seasonings.json` from the app bundle into a normalised name set.
    ///
    /// Falls back to an empty set on a missing/malformed resource — with a DEBUG assertion — so a
    /// build/packaging mistake degrades gracefully (staples simply stop being filtered) instead of
    /// crashing release, while still failing loudly during development and tests.
    private static func loadNames(bundle: Bundle = .main) -> Set<String> {
        guard let url = bundle.url(forResource: Resource.fileName, withExtension: Resource.fileExtension),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("PantryStaples: \(Resource.fileName).\(Resource.fileExtension) missing from bundle")
            return []
        }
        do {
            return try decodeNames(from: data)
        } catch {
            assertionFailure("PantryStaples: failed to decode \(Resource.fileName).\(Resource.fileExtension): \(error)")
            return []
        }
    }

    /// Decodes the grouped staple catalogue (group name → names) and flattens it to one normalised
    /// set. Group keys are presentational only; adding a new group needs no code change. Exposed
    /// `internal` so the schema can be unit-tested without depending on bundle resource copying.
    static func decodeNames(from data: Data) throws -> Set<String> {
        let groups = try JSONDecoder().decode([String: [String]].self, from: data)
        return Set(groups.values.flatMap { $0 }.map(normalize))
    }
}
