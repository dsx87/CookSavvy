import Foundation

// FoundationModels is only available on iOS 26+. The entire file is guarded so that
// older deployment targets can weak-link against the framework cleanly.
#if canImport(FoundationModels)
import FoundationModels

/// Parses natural-language recipe search queries using Apple's on-device Foundation Models.
///
/// Only instantiated when `SystemLanguageModel.default.isAvailable` is true (iOS 26+, Apple
/// Intelligence enabled and fully downloaded). Errors from the model (refusals, rate limits, etc.)
/// are surfaced as `SmartSearchError.parsingFailed` so callers can fall back gracefully.
@available(iOS 26.0, *)
final class FoundationModelsSmartSearchProvider: SmartSearchProviderProtocol {

    func parse(query: String) async throws -> SmartSearchIntent {
        let session = LanguageModelSession {
            Instructions(
                """
                You are a recipe search intent parser for a cooking app. \
                Extract structured fields from the user's natural-language query. \
                Use empty strings for any field not mentioned or implied. \
                Available moods: cozy, fresh, bold, comfort, quick. \
                Available cook times: quick (<30 min), medium (30-60 min), long (>60 min). \
                Available complexity levels: easy, medium, hard. \
                Available dietary restrictions: vegetarian, vegan, glutenFree, dairyFree, nutFree, halal, kosher.
                """
            )
        }
        do {
            let response = try await session.respond(to: query, generating: SearchQueryDTO.self)
            return SmartSearchIntent(from: response.content)
        } catch LanguageModelSession.GenerationError.refusal(let refusal, _) {
            // explanation returns Response<String>; extract .content for the error message.
            let explanation = (try? await refusal.explanation)?.content
            throw SmartSearchError.parsingFailed(explanation)
        }
        // All other GenerationError cases (rate limited, assets unavailable, etc.) propagate up
        // to `runSmartSearch`, which maps them to a user-facing error banner.
    }
}

// MARK: - DTO

/// Wire-contract struct the on-device model generates. String fields avoid optional-handling
/// complexity for the LLM — empty strings are treated as "not specified".
@available(iOS 26.0, *)
@Generable
private struct SearchQueryDTO {
    @Guide(description: "Comma-separated ingredient names the user mentioned. Empty string if none.")
    var ingredients: String
    @Guide(description: "One of: cozy, fresh, bold, comfort, quick. Empty string if not implied.")
    var mood: String
    @Guide(description: "One of: quick, medium, long. Empty string if not specified.")
    var cookTime: String
    @Guide(description: "One of: easy, medium, hard. Empty string if not specified.")
    var complexity: String
    @Guide(description: "Comma-separated from: vegetarian, vegan, glutenFree, dairyFree, nutFree, halal, kosher. Empty string if none.")
    var dietary: String
}

// MARK: - DTO → Domain mapping

@available(iOS 26.0, *)
private extension SmartSearchIntent {
    init(from dto: SearchQueryDTO) {
        let ingredientNames = dto.ingredients
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Lowercase before switching: the model may capitalise enum values ("Quick", "Easy").
        let mood: RecipeMood? = switch dto.mood.trimmingCharacters(in: .whitespaces).lowercased() {
        case "cozy": .cozy
        case "fresh": .fresh
        case "bold": .bold
        case "comfort": .comfort
        case "quick": .quick
        default: nil
        }

        let cookTime: RecipeCookTimeFilter? = switch dto.cookTime.trimmingCharacters(in: .whitespaces).lowercased() {
        case "quick": .quick
        case "medium": .medium
        case "long": .long
        default: nil
        }

        let complexity: RecipeComplexityFilter? = switch dto.complexity.trimmingCharacters(in: .whitespaces).lowercased() {
        case "easy": .easy
        case "medium": .medium
        case "hard": .hard
        default: nil
        }

        // DietaryRestriction rawValues are camelCase; use case-insensitive comparison so "GlutenFree"
        // and "glutenfree" both resolve to .glutenFree.
        let dietary: [DietaryRestriction] = dto.dietary
            .split(separator: ",")
            .compactMap { part in
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                return DietaryRestriction.allCases.first {
                    $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame
                }
            }

        self.init(ingredientNames: ingredientNames, mood: mood, cookTime: cookTime, complexity: complexity, dietary: dietary)
    }
}

#endif
