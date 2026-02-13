import Foundation

struct CookingSession: Identifiable, Hashable {
    let id: Int
    let recipeId: Int
    let recipeTitle: String
    let cookedAt: Date
    let durationSeconds: TimeInterval?

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
