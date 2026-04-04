import Foundation

struct CookingSession: Identifiable, Hashable {
    let id: Int
    let recipeId: Int
    let recipeTitle: String
    let cookedAt: Date
    let durationSeconds: TimeInterval?
    let rating: Int?
    let rescuedIngredients: [Ingredient]

    init(
        id: Int,
        recipeId: Int,
        recipeTitle: String,
        cookedAt: Date,
        durationSeconds: TimeInterval?,
        rating: Int?,
        rescuedIngredients: [Ingredient] = []
    ) {
        self.id = id
        self.recipeId = recipeId
        self.recipeTitle = recipeTitle
        self.cookedAt = cookedAt
        self.durationSeconds = durationSeconds
        self.rating = rating
        self.rescuedIngredients = rescuedIngredients
    }

    var durationFormatted: String? {
        guard let duration = durationSeconds else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
