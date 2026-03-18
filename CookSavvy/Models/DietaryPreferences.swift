import Foundation

enum DietaryRestriction: String, CaseIterable, Codable {
    case vegetarian, vegan, glutenFree, dairyFree, nutFree, halal, kosher

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

protocol DietaryPreferencesProtocol: AnyObject {
    func activeRestrictions() -> Set<DietaryRestriction>
    func toggle(_ restriction: DietaryRestriction)
    func isActive(_ restriction: DietaryRestriction) -> Bool
}

final class DietaryPreferences: DietaryPreferencesProtocol {

    private let defaults: UserDefaults
    private static let key = "dietary_restrictions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func activeRestrictions() -> Set<DietaryRestriction> {
        guard let data = defaults.data(forKey: Self.key) else { return [] }
        do {
            return try JSONDecoder().decode(Set<DietaryRestriction>.self, from: data)
        } catch {
            print("❌ Failed to decode dietary restrictions: \(error)")
            return []
        }
    }

    func toggle(_ restriction: DietaryRestriction) {
        var active = activeRestrictions()
        if active.contains(restriction) {
            active.remove(restriction)
        } else {
            active.insert(restriction)
        }
        save(active)
    }

    func isActive(_ restriction: DietaryRestriction) -> Bool {
        activeRestrictions().contains(restriction)
    }

    private func save(_ restrictions: Set<DietaryRestriction>) {
        do {
            let data = try JSONEncoder().encode(restrictions)
            defaults.set(data, forKey: Self.key)
        } catch {
            print("❌ Failed to encode dietary restrictions: \(error)")
        }
    }
}
