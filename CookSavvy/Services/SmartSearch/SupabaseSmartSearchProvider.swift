import Foundation

/// Fallback smart-search provider that calls the `parse-search-query` Supabase edge function.
///
/// Used on devices where Foundation Models is unavailable (iOS < 26, Apple Intelligence off, or
/// not yet downloaded). The edge function runs DeepSeek non-thinking Flash (`deepseek-v4-flash`)
/// server-side, keeping the API key off-device — consistent with the existing Supabase LLM
/// architecture. This makes Smart Search available to every user, free of charge.
///
/// On a backend failure the UI degrades gracefully: the parse error surfaces via the existing
/// `homeLoadError` banner (see `DiscoverViewModel.runSmartSearch`).
final class SupabaseSmartSearchProvider: SmartSearchProviderProtocol {
    private let clientProvider: SupabaseClientProviderProtocol
    private let decoder: JSONDecoder

    init(clientProvider: SupabaseClientProviderProtocol) {
        self.clientProvider = clientProvider
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func parse(query: String) async throws -> SmartSearchIntent {
        let body = ParseSearchQueryRequest(query: query)
        let data: Data
        do {
            data = try await clientProvider.invokeFunction("parse-search-query", body: body)
        } catch {
            throw SmartSearchError.networkError(error)
        }
        do {
            let response = try decoder.decode(ParseSearchQueryResponse.self, from: data)
            return SmartSearchIntent(from: response)
        } catch {
            // Carry the decode failure detail so `DiscoverViewModel.runSmartSearch`'s logger records
            // what went wrong (the user-facing banner stays generic).
            throw SmartSearchError.parsingFailed(String(describing: error))
        }
    }
}

// MARK: - Wire types

private struct ParseSearchQueryRequest: Encodable {
    let query: String
}

/// Expected response shape from the `parse-search-query` edge function.
/// All fields use snake_case; `keyDecodingStrategy: .convertFromSnakeCase` handles the mapping.
private struct ParseSearchQueryResponse: Decodable {
    let ingredients: [String]
    let mood: String?
    let cookTime: String?
    let complexity: String?
    let dietary: [String]
}

// MARK: - Domain mapping

private extension SmartSearchIntent {
    init(from response: ParseSearchQueryResponse) {
        let mood: RecipeMood? = switch response.mood?.lowercased() {
        case "cozy": .cozy
        case "fresh": .fresh
        case "bold": .bold
        case "comfort": .comfort
        case "quick": .quick
        default: nil
        }

        let cookTime: RecipeCookTimeFilter? = switch response.cookTime?.lowercased() {
        case "quick": .quick
        case "medium": .medium
        case "long": .long
        default: nil
        }

        let complexity: RecipeComplexityFilter? = switch response.complexity?.lowercased() {
        case "easy": .easy
        case "medium": .medium
        case "hard": .hard
        default: nil
        }

        // DietaryRestriction rawValues are camelCase; match case-insensitively so "GlutenFree" and
        // "glutenfree" both resolve to .glutenFree (mirrors FoundationModelsSmartSearchProvider).
        let dietary: [DietaryRestriction] = response.dietary.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            return DietaryRestriction.allCases.first {
                $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame
            }
        }

        self.init(ingredientNames: response.ingredients, mood: mood, cookTime: cookTime, complexity: complexity, dietary: dietary)
    }
}
