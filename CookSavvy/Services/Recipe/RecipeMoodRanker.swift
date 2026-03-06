import Foundation

enum RecipeMood: Int, CaseIterable, Identifiable {
    case cozy = 0
    case fresh = 1
    case bold = 2
    case comfort = 3
    case quick = 4

    var id: Int { rawValue }

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

enum RecipeMoodRanker {
    private struct MoodProfile {
        let keywordGroups: [KeywordGroup]
        let textBonuses: [TextBonus]
        let cookTimeRules: [CookTimeRule]
        let complexityRules: [ComplexityRule]
    }

    private struct KeywordGroup {
        let keywords: [String]
        let weight: Int
    }

    private struct TextBonus {
        let keywords: [String]
        let score: Int
    }

    private struct CookTimeRule {
        let range: ClosedRange<Int>
        let score: Int
    }

    private struct ComplexityRule {
        let levels: Set<ComplexityLevel>
        let score: Int
    }

    private enum ComplexityLevel: String {
        case easy
        case medium
    }

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

    private enum Keywords {
        static let cozy = ["baked", "broth", "chili", "curry", "noodle", "ramen", "roast", "soup", "stew", "warm"]
        static let cozyText = ["comfort", "home"]
        static let fresh = ["avocado", "basil", "cucumber", "fresh", "greens", "herb", "lemon", "lime", "mint", "salad", "tomato", "yogurt"]
        static let bold = ["bold", "buffalo", "chili", "curry", "garlic", "harissa", "kimchi", "miso", "pepper", "smoked", "spicy", "sriracha"]
        static let boldCuisines = ["indian", "korean", "mexican", "sichuan", "thai"]
        static let comfort = ["butter", "casserole", "cheese", "creamy", "gratin", "lasagna", "mac", "pasta", "potato", "rice", "risotto"]
        static let quick = ["bowl", "easy", "fast", "quick", "simple", "weeknight", "wrap"]
    }

    private enum CookTimeRange {
        static let fresh = 0...20
        static let cozy = 20...Int.max
        static let comfort = 25...Int.max
        static let quickVeryShort = 0...15
        static let quickShort = 16...25
    }

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

    private static func score(for recipe: Recipe, mood: RecipeMood) -> Int {
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

    private static func searchableText(for recipe: Recipe) -> String {
        let recipeIngredients = recipe.cleanedIngredients.isEmpty ? recipe.ingredients : recipe.cleanedIngredients
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

    private static func cookTimeMinutes(for recipe: Recipe) -> Int? {
        for info in recipe.additionalInfo.infos {
            if case .time(let cookTime) = info {
                return firstInteger(in: cookTime)
            }
        }
        return nil
    }

    private static func complexityText(for recipe: Recipe) -> String? {
        for info in recipe.additionalInfo.infos {
            if case .complexity(let complexity) = info {
                return complexity.lowercased()
            }
        }
        return nil
    }

    private static func keywordScore(in text: String, keywords: [String], weight: Int) -> Int {
        keywords.reduce(into: 0) { score, keyword in
            if text.contains(keyword) {
                score += weight
            }
        }
    }

    private static func firstInteger(in value: String) -> Int? {
        let digits = value
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .first { !$0.isEmpty }

        guard let digits else { return nil }
        return Int(digits)
    }
}
