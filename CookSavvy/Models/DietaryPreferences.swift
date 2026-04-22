import Foundation

/// Identifies a dietary restriction or lifestyle choice that filters out incompatible recipes.
enum DietaryRestriction: String, CaseIterable, Codable {
    case vegetarian, vegan, glutenFree, dairyFree, nutFree, halal, kosher

    /// Localised name suitable for display in the Settings UI.
    var displayName: String {
        switch self {
        case .vegetarian: return Strings.Dietary.vegetarian
        case .vegan: return Strings.Dietary.vegan
        case .glutenFree: return Strings.Dietary.glutenFree
        case .dairyFree: return Strings.Dietary.dairyFree
        case .nutFree: return Strings.Dietary.nutFree
        case .halal: return Strings.Dietary.halal
        case .kosher: return Strings.Dietary.kosher
        }
    }

    /// Localised short description of what the restriction entails.
    var description: String {
        switch self {
        case .vegetarian: return Strings.Dietary.vegetarianDescription
        case .vegan: return Strings.Dietary.veganDescription
        case .glutenFree: return Strings.Dietary.glutenFreeDescription
        case .dairyFree: return Strings.Dietary.dairyFreeDescription
        case .nutFree: return Strings.Dietary.nutFreeDescription
        case .halal: return Strings.Dietary.halalDescription
        case .kosher: return Strings.Dietary.kosherDescription
        }
    }

    /// SF Symbol name representing this restriction in the UI.
    var icon: String {
        switch self {
        case .vegetarian: return Icons.Dietary.vegetarian
        case .vegan: return Icons.Dietary.vegan
        case .glutenFree: return Icons.Dietary.glutenFree
        case .dairyFree: return Icons.Dietary.dairyFree
        case .nutFree: return Icons.Dietary.nutFree
        case .halal: return Icons.Dietary.halal
        case .kosher: return Icons.Dietary.kosher
        }
    }

    /// Ingredient name substrings that violate this restriction.
    ///
    /// Any recipe whose ingredient list contains one of these substrings is excluded when
    /// the restriction is active. Lists err on the side of caution — `vegan`, for example,
    /// includes all meat *and* all dairy/egg keywords.
    var filterKeywords: [String] {
        switch self {
        case .vegetarian:
            return ["chicken", "beef", "pork", "turkey", "lamb", "duck", "veal", "bacon",
                    "ham", "salami", "prosciutto", "pepperoni", "anchovies", "fish",
                    "salmon", "tuna", "shrimp", "crab", "lobster", "meat", "sausage"]
        case .vegan:
            return ["chicken", "beef", "pork", "turkey", "lamb", "duck", "veal", "bacon",
                    "ham", "salami", "prosciutto", "pepperoni", "anchovies", "fish",
                    "salmon", "tuna", "shrimp", "crab", "lobster", "meat", "sausage",
                    "milk", "cheese", "butter", "cream", "egg", "honey", "yogurt",
                    "gelatin", "whey", "casein"]
        case .glutenFree:
            return ["wheat", "flour", "bread", "pasta", "barley", "rye", "malt",
                    "semolina", "couscous", "bulgur", "farro", "soy sauce",
                    "breadcrumbs", "croutons"]
        case .dairyFree:
            return ["milk", "cheese", "butter", "cream", "yogurt", "whey", "casein",
                    "lactose", "ghee", "sour cream", "ice cream"]
        case .nutFree:
            return ["nut", "almond", "cashew", "walnut", "pecan", "pistachio",
                    "hazelnut", "macadamia", "peanut", "pine nut"]
        case .halal:
            return ["pork", "bacon", "ham", "salami", "prosciutto", "pepperoni",
                    "lard", "gelatin", "alcohol", "wine", "beer", "rum"]
        case .kosher:
            return ["pork", "bacon", "ham", "shrimp", "crab", "lobster", "clam",
                    "oyster", "shellfish", "lard", "gelatin"]
        }
    }
}

/// Read/write interface for the user's active dietary restrictions.
protocol DietaryPreferencesProtocol: AnyObject {
    /// Returns the set of restrictions currently enabled by the user.
    func activeRestrictions() -> Set<DietaryRestriction>
    /// Adds `restriction` if inactive, or removes it if already active.
    func toggle(_ restriction: DietaryRestriction)
    /// Returns `true` if `restriction` is currently enabled.
    func isActive(_ restriction: DietaryRestriction) -> Bool
}

/// Persists the user's active dietary restrictions to `UserDefaults` as JSON-encoded data.
///
/// The full restriction set is stored under a single key as a JSON-encoded
/// `Set<DietaryRestriction>`. Decode/encode errors are logged and treated as an
/// empty set rather than crashing the app.
final class DietaryPreferences: DietaryPreferencesProtocol {

    private let defaults: UserDefaults
    private let logger: any LoggerProtocol
    private static let key = "dietary_restrictions"

    /// Creates a `DietaryPreferences` instance backed by the given `UserDefaults` store.
    /// - Parameters:
    ///   - defaults: The `UserDefaults` suite to read/write. Defaults to `.standard`.
    ///   - logger: Logger used to report encode/decode failures.
    init(
        defaults: UserDefaults = .standard,
        logger: any LoggerProtocol = LoggingService().makeLogger(category: .dietaryPreferences)
    ) {
        self.defaults = defaults
        self.logger = logger
    }

    /// Decodes and returns the persisted restrictions, or an empty set on failure.
    func activeRestrictions() -> Set<DietaryRestriction> {
        guard let data = defaults.data(forKey: Self.key) else { return [] }
        do {
            return try JSONDecoder().decode(Set<DietaryRestriction>.self, from: data)
        } catch {
            logger.error("Failed to decode dietary restrictions: \(error)")
            return []
        }
    }

    /// Toggles `restriction` on or off and persists the updated set.
    func toggle(_ restriction: DietaryRestriction) {
        var active = activeRestrictions()
        if active.contains(restriction) {
            active.remove(restriction)
        } else {
            active.insert(restriction)
        }
        save(active)
    }

    /// Returns `true` if `restriction` is currently active.
    func isActive(_ restriction: DietaryRestriction) -> Bool {
        activeRestrictions().contains(restriction)
    }

    /// JSON-encodes and writes the given restriction set to `UserDefaults`.
    private func save(_ restrictions: Set<DietaryRestriction>) {
        do {
            let data = try JSONEncoder().encode(restrictions)
            defaults.set(data, forKey: Self.key)
        } catch {
            logger.error("Failed to encode dietary restrictions: \(error)")
        }
    }
}
