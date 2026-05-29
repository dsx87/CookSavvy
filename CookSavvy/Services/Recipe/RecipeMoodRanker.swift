import Foundation

/// User-selectable mood filter that controls how the recipe list is reordered.
///
/// Each case maps to a distinct scoring profile in `RecipeMoodRanker` that biases
/// results towards recipes fitting that mood's culinary character.
enum RecipeMood: Int, CaseIterable, Identifiable {
    case cozy = 0
    case fresh = 1
    case bold = 2
    case comfort = 3
    case quick = 4

    var id: Int { rawValue }

    /// Localized display name used in the mood filter bar.
    var name: String {
        switch self {
        case .cozy:
            return Strings.MoodFilter.cozy
        case .fresh:
            return Strings.MoodFilter.fresh
        case .bold:
            return Strings.MoodFilter.bold
        case .comfort:
            return Strings.MoodFilter.comfort
        case .quick:
            return Strings.MoodFilter.quick
        }
    }

    /// SF Symbol name for the mood's tab icon.
    var icon: String {
        switch self {
        case .cozy:
            return Icons.Mood.cozy
        case .fresh:
            return Icons.Mood.fresh
        case .bold:
            return Icons.Mood.bold
        case .comfort:
            return Icons.Mood.comfort
        case .quick:
            return Icons.Mood.quick
        }
    }
}

/// Stateless scoring engine that re-ranks a recipe list to match a selected `RecipeMood`.
///
/// ## Scoring approach
///
/// Each recipe is assigned an integer score based on its `MoodProfile`, which is a
/// data-driven configuration describing three independent signal categories:
///
/// 1. **Keyword groups** — keywords matched against a composite text blob built from
///    the recipe title, tagline, cuisine, and ingredient names. Each matching keyword
///    contributes `weight` points (2 for standard groups, 3 for "featured" groups used
///    by the `.bold` cuisine list).
///
/// 2. **Cook-time rules** — the first integer parsed from the recipe's time `AdditionalInfo`
///    is checked against a `ClosedRange<Int>`. A match adds a small flat bonus, rewarding
///    appropriate cook times (e.g., ≤15 min scores +6 for `.quick`).
///
/// 3. **Complexity rules** — the recipe's complexity `AdditionalInfo` string is compared
///    against a `Set<ComplexityLevel>`. A match adds a flat bonus (e.g., easy complexity +2
///    for `.quick`).
///
/// Ties in score preserve the original input order (stable sort via `enumerated()`).
///
/// All keyword lists, score weights, and cook-time ranges are centralised in the private
/// `Keywords`, `Score`, and `CookTimeRange` enums so changes to the ranking logic
/// are confined to those namespaces.
enum RecipeMoodRanker {
    /// Groups a keyword list with a per-match point value.
    private struct MoodProfile {
        let keywordGroups: [KeywordGroup]
        let textBonuses: [TextBonus]
        let cookTimeRules: [CookTimeRule]
        let complexityRules: [ComplexityRule]
    }

    /// A set of keywords that each contribute `weight` points when found in searchable text.
    private struct KeywordGroup {
        let keywords: [String]
        let weight: Int
    }

    /// A flat bonus applied when any keyword from the list is present in recipe text.
    private struct TextBonus {
        let keywords: [String]
        let score: Int
    }

    /// Applies `score` points when the recipe's cook time (in minutes) falls within `range`.
    private struct CookTimeRule {
        let range: ClosedRange<Int>
        let score: Int
    }

    /// Applies `score` points when the recipe's complexity matches one of the given `levels`.
    private struct ComplexityRule {
        let levels: Set<ComplexityLevel>
        let score: Int
    }

    /// Normalised complexity values extracted from recipe `AdditionalInfo`.
    private enum ComplexityLevel: String {
        case easy
        case medium
    }

    /// Centralised score constants — adjust here to tune ranking sensitivity per mood.
    private enum Score {
        static let standardKeywordMatch = 2
        static let featuredKeywordMatch = 3
        static let cozyCookTimeBonus = 2
        static let cozyTextBonus = 2
        static let freshCookTimeBonus = 1
        static let comfortCookTimeBonus = 1
        static let comfortComplexityBonus = 1
        static let quickVeryShortCookTimeBonus = 6
        static let quickShortCookTimeBonus = 3
        static let quickComplexityBonus = 2
    }

    /// Keyword vocabularies for each mood, split into logical groups.
    private enum Keywords {
        static let cozy = ["baked", "broth", "chili", "curry", "noodle", "ramen", "roast", "soup", "stew", "warm"]
        static let cozyText = ["comfort", "home"]
        static let fresh = ["avocado", "basil", "cucumber", "fresh", "greens", "herb", "lemon", "lime", "mint", "salad", "tomato", "yogurt"]
        static let bold = ["bold", "buffalo", "chili", "curry", "garlic", "harissa", "kimchi", "miso", "pepper", "smoked", "spicy", "sriracha"]
        static let boldCuisines = ["indian", "korean", "mexican", "sichuan", "thai"]
        static let comfort = ["butter", "casserole", "cheese", "creamy", "gratin", "lasagna", "mac", "pasta", "potato", "rice", "risotto"]
        static let quick = ["bowl", "easy", "fast", "quick", "simple", "weeknight", "wrap"]
    }

    /// Cook-time minute ranges used by `CookTimeRule` entries.
    private enum CookTimeRange {
        static let fresh = 0...20
        static let cozy = 20...Int.max
        static let comfort = 25...Int.max
        static let quickVeryShort = 0...15
        static let quickShort = 16...25
    }

    /// Pre-built mood profiles keyed by `RecipeMood`. Adding a new mood requires a
    /// corresponding entry here with appropriate keyword groups, bonuses, and rules.
    private static let moodProfiles: [RecipeMood: MoodProfile] = [
        .cozy: MoodProfile(
            keywordGroups: [
                KeywordGroup(keywords: Keywords.cozy, weight: Score.standardKeywordMatch)
            ],
            textBonuses: [
                TextBonus(keywords: Keywords.cozyText, score: Score.cozyTextBonus)
            ],
            cookTimeRules: [
                CookTimeRule(range: CookTimeRange.cozy, score: Score.cozyCookTimeBonus)
            ],
            complexityRules: []
        ),
        .fresh: MoodProfile(
            keywordGroups: [
                KeywordGroup(keywords: Keywords.fresh, weight: Score.standardKeywordMatch)
            ],
            textBonuses: [],
            cookTimeRules: [
                CookTimeRule(range: CookTimeRange.fresh, score: Score.freshCookTimeBonus)
            ],
            complexityRules: []
        ),
        .bold: MoodProfile(
            keywordGroups: [
                KeywordGroup(keywords: Keywords.bold, weight: Score.standardKeywordMatch),
                KeywordGroup(keywords: Keywords.boldCuisines, weight: Score.featuredKeywordMatch)
            ],
            textBonuses: [],
            cookTimeRules: [],
            complexityRules: []
        ),
        .comfort: MoodProfile(
            keywordGroups: [
                KeywordGroup(keywords: Keywords.comfort, weight: Score.standardKeywordMatch)
            ],
            textBonuses: [],
            cookTimeRules: [
                CookTimeRule(range: CookTimeRange.comfort, score: Score.comfortCookTimeBonus)
            ],
            complexityRules: [
                ComplexityRule(levels: [.easy, .medium], score: Score.comfortComplexityBonus)
            ]
        ),
        .quick: MoodProfile(
            keywordGroups: [
                KeywordGroup(keywords: Keywords.quick, weight: Score.standardKeywordMatch)
            ],
            textBonuses: [],
            cookTimeRules: [
                CookTimeRule(range: CookTimeRange.quickVeryShort, score: Score.quickVeryShortCookTimeBonus),
                CookTimeRule(range: CookTimeRange.quickShort, score: Score.quickShortCookTimeBonus)
            ],
            complexityRules: [
                ComplexityRule(levels: [.easy], score: Score.quickComplexityBonus)
            ]
        )
    ]

    /// Returns `recipes` sorted by their relevance to `mood`, highest score first.
    ///
    /// Ties preserve the original input order (stable sort via `enumerated().offset`).
    /// - Parameters:
    ///   - recipes: The candidate recipe list to reorder.
    ///   - mood: The mood filter selected by the user.
    /// - Returns: The same recipes in mood-ranked order.
    static func rank(_ recipes: [Recipe], for mood: RecipeMood) -> [Recipe] {
        recipes
            .enumerated()
            .sorted { lhs, rhs in
                let lhsScore = score(for: lhs.element, mood: mood)
                let rhsScore = score(for: rhs.element, mood: mood)
                if lhsScore == rhsScore {
                    return lhs.offset < rhs.offset
                }
                return lhsScore > rhsScore
            }
            .map(\.element)
    }

    /// Returns the integer mood score used by composite rankers to break ties.
    static func score(for recipe: Recipe, mood: RecipeMood) -> Int {
        let text = searchableText(for: recipe)
        let cookTime = cookTimeMinutes(for: recipe)
        let complexity = complexityText(for: recipe).flatMap(ComplexityLevel.init(rawValue:))

        guard let profile = moodProfiles[mood] else { return 0 }

        var score = profile.keywordGroups.reduce(into: 0) { total, group in
            total += keywordScore(in: text, keywords: group.keywords, weight: group.weight)
        }

        score += profile.textBonuses.reduce(into: 0) { total, bonus in
            if bonus.keywords.contains(where: text.contains) {
                total += bonus.score
            }
        }

        if let cookTime {
            score += profile.cookTimeRules.reduce(into: 0) { total, rule in
                if rule.range.contains(cookTime) {
                    total += rule.score
                }
            }
        }

        if let complexity {
            score += profile.complexityRules.reduce(into: 0) { total, rule in
                if rule.levels.contains(complexity) {
                    total += rule.score
                }
            }
        }

        return score
    }

    /// Builds a single lowercased string from the recipe's title, tagline, cuisine, and
    /// ingredient names — the search surface used by all keyword matching.
    private static func searchableText(for recipe: Recipe) -> String {
        let recipeIngredients = recipe.cleanedIngredients
        var parts: [String] = [recipe.title]
        if let tagline = recipe.tagline {
            parts.append(tagline)
        }
        if let cuisine = recipe.cuisine {
            parts.append(cuisine)
        }
        parts.append(contentsOf: recipeIngredients.map(\.name))
        return parts.joined(separator: " ").lowercased()
    }

    /// Extracts the numeric cook-time value (in minutes) from the recipe's `AdditionalInfo`.
    /// Returns `nil` if no time info is present.
    private static func cookTimeMinutes(for recipe: Recipe) -> Int? {
        for info in recipe.additionalInfo.infos {
            if case .time(let cookTime) = info {
                return extractCookTimeMinutes(from: cookTime)
            }
        }
        return nil
    }

    /// Returns the lowercased complexity string from the recipe's `AdditionalInfo`, or `nil` if absent.
    private static func complexityText(for recipe: Recipe) -> String? {
        for info in recipe.additionalInfo.infos {
            if case .complexity(let complexity) = info {
                return complexity.lowercased()
            }
        }
        return nil
    }

    /// Counts keyword occurrences in `text`, multiplying each hit by `weight`.
    /// - Parameters:
    ///   - text: The composite searchable string for a recipe.
    ///   - keywords: Keywords to search for.
    ///   - weight: Points awarded per matched keyword.
    /// - Returns: Cumulative score from all matched keywords.
    private static func keywordScore(in text: String, keywords: [String], weight: Int) -> Int {
        keywords.reduce(into: 0) { score, keyword in
            if text.contains(keyword) {
                score += weight
            }
        }
    }

    /// Extracts the first contiguous run of decimal digits from `value` and converts it to `Int`.
    static func extractCookTimeMinutes(from value: String) -> Int? {
        firstInteger(in: value)
    }

    /// Extracts the first contiguous run of decimal digits from `value` and converts it to `Int`.
    /// Used to parse cook-time strings such as `"25 min"` or `"1 hr 10 min"` → `1`.
    private static func firstInteger(in value: String) -> Int? {
        let digits = value
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .first { !$0.isEmpty }

        guard let digits else { return nil }
        return Int(digits)
    }
}
