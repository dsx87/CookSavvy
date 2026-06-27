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
/// The curated rules live in the bundled **`Seasonings.json`** resource rather than a code literal,
/// so they can be tuned as data without touching Swift — mirroring how `Substitutions.json` backs the
/// substitution catalogue. The file is loaded once, lazily, into `catalog`.
///
/// **Matching** (mirrors the real dataset, whose `basicComponent` values carry many descriptor
/// variants — "sea salt", "cumin seeds", "black peppercorns", "cayenne pepper"):
/// - `stapleWords` match as a **whole word anywhere** in the name, so a single token catches all its
///   variants. Used only for tokens that never appear inside a real ingredient (`salt`, `cumin`,
///   `peppercorns`…).
/// - `stapleExact` match the **full name**, carrying the ambiguous cases where a loose match would
///   hide produce — the `pepper` family (so "bell pepper"/"chile pepper" stay selectable), multiword
///   blends, seeds whose parent is a vegetable/herb ("fennel seed" vs the "fennel" bulb), neutral
///   oils (flavour oils like sesame stay selectable), and basic vinegars.
/// - `notStaple` lists the few non-staples that contain a `stapleWord` ("salt cod", "sugar snap
///   peas") and wins over both.
///
/// Scope stays *narrow* (pantry staples only): salt, pepper, oils, water, sugar, vinegar, and dried
/// spices. Fresh herbs (basil, cilantro) and condiments/sauces (soy sauce, pesto, the mustard
/// *condiment*) are intentionally selectable. Note: `mustard seed` is a staple; `mustard` is not.
///
/// `nonisolated` (not pinned to the main actor): a pure, stateless value utility, sibling to
/// `IngredientCategoryClassifier`.
nonisolated enum PantryStaples {

    /// `true` when `name` resolves to a pantry staple under the `Seasonings.json` rules.
    static func isStaple(_ name: String) -> Bool {
        let normalized = normalize(name)
        guard !normalized.isEmpty else { return false }
        if catalog.notStaple.contains(normalized) { return false }
        let words = normalized.split(whereSeparator: { !$0.isLetter }).map(String.init)
        // A prepared-food / condiment noun ("cookie", "sauce", "relish", "syrup"…) means this is a
        // dish, not a seasoning — even when it also contains a staple word ("sugar cookie",
        // "saffron mayonnaise", "pomegranate-cumin dressing"). This guard wins over both staple rules.
        if words.contains(where: { catalog.notStapleWords.contains($0) }) { return false }
        if catalog.exact.contains(normalized) { return true }
        return words.contains { catalog.words.contains($0) }
    }

    /// Returns `ingredients` with all pantry staples removed, preserving order.
    static func excludingStaples(_ ingredients: [Ingredient]) -> [Ingredient] {
        ingredients.filter { !isStaple($0.name) }
    }

    /// The staple-matching rules, loaded once from the bundled `Seasonings.json` resource.
    static let catalog: Catalog = loadCatalog()

    /// Normalised staple-matching rules. `words` match as whole tokens, `exact` as full names;
    /// `notStaple` (full name) and `notStapleWords` (any token = a prepared dish) override both.
    struct Catalog: Equatable {
        let words: Set<String>
        let exact: Set<String>
        let notStaple: Set<String>
        let notStapleWords: Set<String>

        /// An empty catalogue — the graceful-degradation fallback when the resource can't be read.
        static let empty = Catalog(words: [], exact: [], notStaple: [], notStapleWords: [])
    }

    /// Trims and lowercases a name for consistent comparison.
    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Loading

    private enum Resource {
        static let fileName = "Seasonings"
        static let fileExtension = "json"
    }

    /// Reads `Seasonings.json` from the app bundle into a normalised ``Catalog``.
    ///
    /// Falls back to an empty catalogue on a missing/malformed resource — with a DEBUG assertion — so
    /// a build/packaging mistake degrades gracefully (staples simply stop being filtered) instead of
    /// crashing release, while still failing loudly during development and tests.
    private static func loadCatalog(bundle: Bundle = .main) -> Catalog {
        guard let url = bundle.url(forResource: Resource.fileName, withExtension: Resource.fileExtension),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("PantryStaples: \(Resource.fileName).\(Resource.fileExtension) missing from bundle")
            return .empty
        }
        do {
            return try decodeCatalog(from: data)
        } catch {
            assertionFailure("PantryStaples: failed to decode \(Resource.fileName).\(Resource.fileExtension): \(error)")
            return .empty
        }
    }

    /// Wire model for `Seasonings.json`. Each list is optional so a partial file still yields a
    /// usable catalogue, and the leading `_comment` key in the file is simply ignored.
    private struct CatalogDTO: Decodable {
        let stapleWords: [String]
        let stapleExact: [String]
        let notStaple: [String]
        let notStapleWords: [String]

        enum CodingKeys: String, CodingKey {
            case stapleWords, stapleExact, notStaple, notStapleWords
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            stapleWords = try c.decodeIfPresent([String].self, forKey: .stapleWords) ?? []
            stapleExact = try c.decodeIfPresent([String].self, forKey: .stapleExact) ?? []
            notStaple = try c.decodeIfPresent([String].self, forKey: .notStaple) ?? []
            notStapleWords = try c.decodeIfPresent([String].self, forKey: .notStapleWords) ?? []
        }
    }

    /// Decodes and normalises the staple catalogue. Exposed `internal` so the schema can be
    /// unit-tested without depending on bundle resource copying.
    static func decodeCatalog(from data: Data) throws -> Catalog {
        let dto = try JSONDecoder().decode(CatalogDTO.self, from: data)
        return Catalog(
            words: Set(dto.stapleWords.map(normalize)),
            exact: Set(dto.stapleExact.map(normalize)),
            notStaple: Set(dto.notStaple.map(normalize)),
            notStapleWords: Set(dto.notStapleWords.map(normalize))
        )
    }
}
