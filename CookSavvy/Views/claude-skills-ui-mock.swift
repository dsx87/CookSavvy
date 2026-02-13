import SwiftUI

// ════════════════════════════════════════════════════════════
// MARK: - Design System V2 — Dark Immersive
// ════════════════════════════════════════════════════════════

private enum DS2 {
    enum Colors {
        static let bg = Color(red: 0.06, green: 0.06, blue: 0.09)
        static let surface = Color(red: 0.11, green: 0.11, blue: 0.15)
        static let surfaceLight = Color(red: 0.16, green: 0.16, blue: 0.21)
        static let card = Color(red: 0.13, green: 0.13, blue: 0.18)

        static let accent = Color(red: 1.0, green: 0.55, blue: 0.20)    // warm orange
        static let accentSoft = Color(red: 1.0, green: 0.55, blue: 0.20).opacity(0.15)
        static let mint = Color(red: 0.30, green: 0.85, blue: 0.72)
        static let mintSoft = Color(red: 0.30, green: 0.85, blue: 0.72).opacity(0.15)
        static let rose = Color(red: 0.95, green: 0.35, blue: 0.50)
        static let roseSoft = Color(red: 0.95, green: 0.35, blue: 0.50).opacity(0.15)
        static let lavender = Color(red: 0.65, green: 0.50, blue: 0.95)
        static let lavenderSoft = Color(red: 0.65, green: 0.50, blue: 0.95).opacity(0.15)
        static let sky = Color(red: 0.35, green: 0.65, blue: 1.0)
        static let skySoft = Color(red: 0.35, green: 0.65, blue: 1.0).opacity(0.15)
        static let gold = Color(red: 1.0, green: 0.82, blue: 0.30)

        static let text1 = Color.white
        static let text2 = Color.white.opacity(0.65)
        static let text3 = Color.white.opacity(0.35)
        static let divider = Color.white.opacity(0.08)
    }

    static let r12: CGFloat = 12
    static let r16: CGFloat = 16
    static let r20: CGFloat = 20
    static let r24: CGFloat = 24
    static let r32: CGFloat = 32
}

// neonGlow / frostCard modifiers now live in Theme/ViewModifiers.swift

// ════════════════════════════════════════════════════════════
// MARK: - Mock Data V2
// ════════════════════════════════════════════════════════════

fileprivate struct V2Recipe: Identifiable, Hashable {
    let id: Int
    let name: String
    let tagline: String
    let cookTime: Int
    let difficulty: String
    let servings: Int
    let calories: Int
    let mood: String
    let ingredients: [String]
    let steps: [V2Step]
    let gradient: [Color]
    let emoji: String
    var isSaved: Bool
    let rating: Double
    let author: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (l: V2Recipe, r: V2Recipe) -> Bool { l.id == r.id }
}

fileprivate struct V2Step: Identifiable, Hashable {
    let id: Int
    let text: String
    let timerMinutes: Int?
}

fileprivate struct V2Mood: Identifiable {
    let id: Int
    let name: String
    let icon: String
    let color: Color
    let gradient: [Color]
}

fileprivate struct V2Achievement: Identifiable {
    let id: Int
    let title: String
    let description: String
    let icon: String
    let color: Color
    let progress: Double
    let isUnlocked: Bool
}

fileprivate struct V2Ingredient: Identifiable, Hashable {
    let id: Int
    let name: String
    let emoji: String
    let category: String
}

fileprivate struct V2IngredientCategory: Identifiable {
    let id: Int
    let name: String
    let emoji: String
    let color: Color
}

fileprivate enum V2Data {
    static let ingredientCategories: [V2IngredientCategory] = [
        .init(id: 0, name: "Proteins", emoji: "🥩", color: DS2.Colors.rose),
        .init(id: 1, name: "Veggies", emoji: "🥬", color: DS2.Colors.mint),
        .init(id: 2, name: "Dairy", emoji: "🧀", color: DS2.Colors.gold),
        .init(id: 3, name: "Grains", emoji: "🌾", color: DS2.Colors.accent),
        .init(id: 4, name: "Fruits", emoji: "🍎", color: DS2.Colors.rose),
        .init(id: 5, name: "Spices", emoji: "🌶️", color: DS2.Colors.lavender),
    ]

    static let ingredients: [V2Ingredient] = [
        .init(id: 0, name: "Chicken", emoji: "🍗", category: "Proteins"),
        .init(id: 1, name: "Salmon", emoji: "🐟", category: "Proteins"),
        .init(id: 2, name: "Eggs", emoji: "🥚", category: "Proteins"),
        .init(id: 3, name: "Ground Beef", emoji: "🥩", category: "Proteins"),
        .init(id: 4, name: "Tomato", emoji: "🍅", category: "Veggies"),
        .init(id: 5, name: "Spinach", emoji: "🥬", category: "Veggies"),
        .init(id: 6, name: "Onion", emoji: "🧅", category: "Veggies"),
        .init(id: 7, name: "Garlic", emoji: "🧄", category: "Veggies"),
        .init(id: 8, name: "Bell Pepper", emoji: "🫑", category: "Veggies"),
        .init(id: 9, name: "Avocado", emoji: "🥑", category: "Veggies"),
        .init(id: 10, name: "Cheese", emoji: "🧀", category: "Dairy"),
        .init(id: 11, name: "Butter", emoji: "🧈", category: "Dairy"),
        .init(id: 12, name: "Milk", emoji: "🥛", category: "Dairy"),
        .init(id: 13, name: "Rice", emoji: "🍚", category: "Grains"),
        .init(id: 14, name: "Pasta", emoji: "🍝", category: "Grains"),
        .init(id: 15, name: "Bread", emoji: "🍞", category: "Grains"),
        .init(id: 16, name: "Lemon", emoji: "🍋", category: "Fruits"),
        .init(id: 17, name: "Mango", emoji: "🥭", category: "Fruits"),
        .init(id: 18, name: "Chili", emoji: "🌶️", category: "Spices"),
        .init(id: 19, name: "Ginger", emoji: "🫚", category: "Spices"),
    ]

    static let moods: [V2Mood] = [
        .init(id: 0, name: "Cozy", icon: "flame.fill", color: DS2.Colors.accent,
              gradient: [Color(red: 1.0, green: 0.55, blue: 0.20), Color(red: 0.85, green: 0.30, blue: 0.15)]),
        .init(id: 1, name: "Fresh", icon: "leaf.fill", color: DS2.Colors.mint,
              gradient: [Color(red: 0.30, green: 0.85, blue: 0.72), Color(red: 0.15, green: 0.65, blue: 0.55)]),
        .init(id: 2, name: "Bold", icon: "bolt.fill", color: DS2.Colors.rose,
              gradient: [Color(red: 0.95, green: 0.35, blue: 0.50), Color(red: 0.75, green: 0.20, blue: 0.40)]),
        .init(id: 3, name: "Comfort", icon: "heart.fill", color: DS2.Colors.lavender,
              gradient: [Color(red: 0.65, green: 0.50, blue: 0.95), Color(red: 0.45, green: 0.30, blue: 0.80)]),
        .init(id: 4, name: "Quick", icon: "timer", color: DS2.Colors.sky,
              gradient: [Color(red: 0.35, green: 0.65, blue: 1.0), Color(red: 0.20, green: 0.45, blue: 0.85)]),
    ]

    static let recipes: [V2Recipe] = [
        .init(id: 0, name: "Midnight Ramen", tagline: "Soul-warming noodles with a kick",
              cookTime: 25, difficulty: "Easy", servings: 2, calories: 480, mood: "Cozy",
              ingredients: ["Ramen noodles", "Soft-boiled eggs", "Chashu pork", "Nori", "Green onions", "Miso paste", "Dashi stock"],
              steps: [
                .init(id: 0, text: "Bring dashi stock to a gentle simmer", timerMinutes: 5),
                .init(id: 1, text: "Dissolve miso paste into the broth", timerMinutes: nil),
                .init(id: 2, text: "Cook ramen noodles until al dente", timerMinutes: 3),
                .init(id: 3, text: "Slice chashu pork and halve the eggs", timerMinutes: nil),
                .init(id: 4, text: "Assemble bowls: noodles, broth, toppings", timerMinutes: nil),
                .init(id: 5, text: "Garnish with nori and sliced green onions", timerMinutes: nil),
              ],
              gradient: [Color(red: 0.95, green: 0.50, blue: 0.20), Color(red: 0.65, green: 0.18, blue: 0.10)],
              emoji: "🍜", isSaved: true, rating: 4.8, author: "Chef Yuki"),
        .init(id: 1, name: "Garden Glow Bowl", tagline: "Vibrant greens, powerful energy",
              cookTime: 15, difficulty: "Easy", servings: 1, calories: 320, mood: "Fresh",
              ingredients: ["Quinoa", "Kale", "Avocado", "Edamame", "Mango", "Tahini", "Lime"],
              steps: [
                .init(id: 0, text: "Cook quinoa according to package", timerMinutes: 12),
                .init(id: 1, text: "Massage kale with olive oil and salt", timerMinutes: nil),
                .init(id: 2, text: "Dice mango and slice avocado", timerMinutes: nil),
                .init(id: 3, text: "Arrange everything in a bowl", timerMinutes: nil),
                .init(id: 4, text: "Drizzle with tahini-lime dressing", timerMinutes: nil),
              ],
              gradient: [Color(red: 0.30, green: 0.80, blue: 0.50), Color(red: 0.12, green: 0.55, blue: 0.35)],
              emoji: "🥗", isSaved: false, rating: 4.6, author: "Green Kitchen"),
        .init(id: 2, name: "Volcanic Shakshuka", tagline: "Fiery eggs in spiced tomato",
              cookTime: 30, difficulty: "Medium", servings: 3, calories: 350, mood: "Bold",
              ingredients: ["Eggs", "Tomatoes", "Bell peppers", "Cumin", "Paprika", "Feta", "Cilantro", "Crusty bread"],
              steps: [
                .init(id: 0, text: "Sauté peppers and onions until soft", timerMinutes: 5),
                .init(id: 1, text: "Add spices, cook until fragrant", timerMinutes: 1),
                .init(id: 2, text: "Pour in crushed tomatoes, simmer", timerMinutes: 10),
                .init(id: 3, text: "Create wells, crack eggs into sauce", timerMinutes: nil),
                .init(id: 4, text: "Cover and cook until eggs set", timerMinutes: 8),
                .init(id: 5, text: "Top with feta and fresh cilantro", timerMinutes: nil),
              ],
              gradient: [Color(red: 0.90, green: 0.25, blue: 0.20), Color(red: 0.60, green: 0.10, blue: 0.08)],
              emoji: "🍳", isSaved: true, rating: 4.9, author: "Spice Route"),
        .init(id: 3, name: "Velvet Mac & Cheese", tagline: "The ultimate comfort classic",
              cookTime: 35, difficulty: "Easy", servings: 4, calories: 550, mood: "Comfort",
              ingredients: ["Elbow pasta", "Sharp cheddar", "Gruyère", "Butter", "Flour", "Milk", "Breadcrumbs"],
              steps: [
                .init(id: 0, text: "Cook pasta until just under al dente", timerMinutes: 8),
                .init(id: 1, text: "Make roux with butter and flour", timerMinutes: 2),
                .init(id: 2, text: "Gradually whisk in warm milk", timerMinutes: 5),
                .init(id: 3, text: "Melt in both cheeses, stir smooth", timerMinutes: nil),
                .init(id: 4, text: "Fold in pasta, pour into baking dish", timerMinutes: nil),
                .init(id: 5, text: "Top with breadcrumbs, bake golden", timerMinutes: 15),
              ],
              gradient: [Color(red: 0.85, green: 0.65, blue: 0.20), Color(red: 0.60, green: 0.40, blue: 0.10)],
              emoji: "🧀", isSaved: true, rating: 4.7, author: "Home Classics"),
        .init(id: 4, name: "5-Minute Pesto Wrap", tagline: "Lightning-fast, incredibly tasty",
              cookTime: 5, difficulty: "Easy", servings: 1, calories: 380, mood: "Quick",
              ingredients: ["Tortilla", "Pesto", "Mozzarella", "Tomato", "Arugula", "Balsamic glaze"],
              steps: [
                .init(id: 0, text: "Spread pesto across the tortilla", timerMinutes: nil),
                .init(id: 1, text: "Layer mozzarella, tomato, arugula", timerMinutes: nil),
                .init(id: 2, text: "Drizzle with balsamic glaze", timerMinutes: nil),
                .init(id: 3, text: "Roll tightly and slice in half", timerMinutes: nil),
              ],
              gradient: [Color(red: 0.35, green: 0.65, blue: 0.95), Color(red: 0.18, green: 0.40, blue: 0.75)],
              emoji: "🌯", isSaved: false, rating: 4.3, author: "Quick Bites"),
        .init(id: 5, name: "Miso Glazed Salmon", tagline: "Umami perfection on a plate",
              cookTime: 20, difficulty: "Medium", servings: 2, calories: 420, mood: "Bold",
              ingredients: ["Salmon fillets", "White miso", "Mirin", "Sake", "Brown sugar", "Ginger", "Bok choy"],
              steps: [
                .init(id: 0, text: "Mix miso, mirin, sake, and sugar into glaze", timerMinutes: nil),
                .init(id: 1, text: "Marinate salmon for at least 30 min", timerMinutes: nil),
                .init(id: 2, text: "Broil salmon on high until caramelized", timerMinutes: 6),
                .init(id: 3, text: "Sauté bok choy with ginger", timerMinutes: 3),
                .init(id: 4, text: "Serve salmon over bok choy", timerMinutes: nil),
              ],
              gradient: [Color(red: 0.90, green: 0.45, blue: 0.30), Color(red: 0.70, green: 0.25, blue: 0.18)],
              emoji: "🐟", isSaved: false, rating: 4.9, author: "Umami Lab"),
    ]

    static let userRecipes: [V2Recipe] = [
        .init(id: 100, name: "Grandma's Soup", tagline: "Family recipe passed down generations",
              cookTime: 45, difficulty: "Easy", servings: 6, calories: 280, mood: "Comfort",
              ingredients: ["Chicken broth", "Carrots", "Celery", "Egg noodles", "Thyme", "Bay leaf"],
              steps: [
                .init(id: 0, text: "Sauté carrots and celery until soft", timerMinutes: 5),
                .init(id: 1, text: "Add chicken broth and bring to boil", timerMinutes: 10),
                .init(id: 2, text: "Add noodles and herbs, simmer", timerMinutes: 15),
                .init(id: 3, text: "Season to taste and serve hot", timerMinutes: nil),
              ],
              gradient: [Color(red: 0.85, green: 0.55, blue: 0.25), Color(red: 0.60, green: 0.35, blue: 0.15)],
              emoji: "🍲", isSaved: true, rating: 5.0, author: "Me"),
        .init(id: 101, name: "Morning Smoothie", tagline: "Quick energy boost to start the day",
              cookTime: 5, difficulty: "Easy", servings: 1, calories: 210, mood: "Fresh",
              ingredients: ["Banana", "Blueberries", "Spinach", "Almond milk", "Honey"],
              steps: [
                .init(id: 0, text: "Add all ingredients to blender", timerMinutes: nil),
                .init(id: 1, text: "Blend until smooth", timerMinutes: 1),
                .init(id: 2, text: "Pour and enjoy immediately", timerMinutes: nil),
              ],
              gradient: [Color(red: 0.45, green: 0.75, blue: 0.55), Color(red: 0.25, green: 0.55, blue: 0.40)],
              emoji: "🥤", isSaved: true, rating: 4.5, author: "Me"),
        .init(id: 102, name: "Spicy Fried Rice", tagline: "Leftover rice transformed",
              cookTime: 15, difficulty: "Easy", servings: 2, calories: 390, mood: "Bold",
              ingredients: ["Cooked rice", "Eggs", "Soy sauce", "Sriracha", "Green onions", "Sesame oil"],
              steps: [
                .init(id: 0, text: "Heat sesame oil in a large wok", timerMinutes: nil),
                .init(id: 1, text: "Scramble eggs, set aside", timerMinutes: 2),
                .init(id: 2, text: "Stir-fry rice on high heat", timerMinutes: 5),
                .init(id: 3, text: "Add sauces, eggs, and green onions", timerMinutes: nil),
              ],
              gradient: [Color(red: 0.90, green: 0.35, blue: 0.20), Color(red: 0.70, green: 0.20, blue: 0.12)],
              emoji: "🍳", isSaved: true, rating: 4.2, author: "Me"),
    ]

    static let achievements: [V2Achievement] = [
        .init(id: 0, title: "First Flame", description: "Cook your first recipe", icon: "flame.fill", color: DS2.Colors.accent, progress: 1.0, isUnlocked: true),
        .init(id: 1, title: "Week Warrior", description: "Cook 7 days in a row", icon: "calendar", color: DS2.Colors.mint, progress: 0.71, isUnlocked: false),
        .init(id: 2, title: "Globe Trotter", description: "Try 5 different cuisines", icon: "globe", color: DS2.Colors.sky, progress: 0.6, isUnlocked: false),
        .init(id: 3, title: "Speed Demon", description: "Cook 10 recipes under 15 min", icon: "bolt.fill", color: DS2.Colors.gold, progress: 0.3, isUnlocked: false),
        .init(id: 4, title: "Master Chef", description: "Complete 50 recipes", icon: "star.fill", color: DS2.Colors.rose, progress: 0.24, isUnlocked: false),
    ]
}

// ════════════════════════════════════════════════════════════
// MARK: - Shared Components V2
// ════════════════════════════════════════════════════════════

// Gradient recipe image with emoji
private struct V2RecipeImage: View {
    let gradient: [Color]
    let emoji: String
    var height: CGFloat = 200

    var body: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(emoji)
                .font(.system(size: height * 0.3))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        }
        .frame(height: height)
        .clipped()
    }
}

// Mood pill selector
private struct MoodPill: View {
    let mood: V2Mood
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: mood.icon)
                .font(.system(size: 14, weight: .bold))
            Text(mood.name)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(isSelected ? .white : mood.color)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(isSelected ? AnyShapeStyle(
                    LinearGradient(colors: mood.gradient, startPoint: .leading, endPoint: .trailing)
                ) : AnyShapeStyle(mood.color.opacity(0.12)))
        )
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? Color.clear : mood.color.opacity(0.2), lineWidth: 1)
        )
        .neonGlow(isSelected ? mood.color : .clear, radius: isSelected ? 6 : 0)
    }
}

// Star rating
private struct StarRating: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: Double(i) <= rating ? "star.fill" : (Double(i) - 0.5 <= rating ? "star.leadinghalf.filled" : "star"))
                    .font(.system(size: 10))
                    .foregroundStyle(DS2.Colors.gold)
            }
        }
    }
}

// ════════════════════════════════════════════════════════════
// MARK: - 1. Discover Screen (Two-State)
// ════════════════════════════════════════════════════════════

fileprivate struct V2DiscoverView: View {
    @State private var selectedIngredients: [V2Ingredient] = []
    @State private var selectedMood: Int? = nil
    @State private var searchText = ""
    @State private var selectedCategory: Int? = nil
    @State private var showCreateRecipe = false

    private var hasIngredients: Bool { !selectedIngredients.isEmpty }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<21: return "Good Evening"
        default: return "Late Night Cravings?"
        }
    }

    private var timeEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "☀️"
        case 12..<17: return "🌤️"
        case 17..<21: return "🌅"
        default: return "🌙"
        }
    }

    private var filteredIngredients: [V2Ingredient] {
        var items = V2Data.ingredients
        if let catIdx = selectedCategory {
            let catName = V2Data.ingredientCategories[catIdx].name
            items = items.filter { $0.category == catName }
        }
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return items
    }

    private var filteredRecipes: [V2Recipe] {
        var results = V2Data.recipes
        if let moodIdx = selectedMood {
            let moodName = V2Data.moods[moodIdx].name
            results = results.filter { $0.mood == moodName }
        }
        return results
    }

    private var recentRecipes: [V2Recipe] {
        Array(V2Data.recipes.prefix(4))
    }

    private var savedRecipes: [V2Recipe] {
        V2Data.recipes.filter { $0.isSaved }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if hasIngredients {
                resultsState
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ingredientSelectionState
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .background(DS2.Colors.bg)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: hasIngredients)
        .sheet(isPresented: $showCreateRecipe) {
            V2CreateRecipeView()
        }
    }

    // ── State 1: Ingredient Selection ──────────────────────

    private var ingredientSelectionState: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(greeting) \(timeEmoji)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(DS2.Colors.text3)
                        Text("What's in your\nkitchen?")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(DS2.Colors.text1)
                        Text("Add ingredients and we'll find recipes for you")
                            .font(.system(size: 15))
                            .foregroundStyle(DS2.Colors.text2)
                    }
                    .padding(.top, 8)

                    // Search bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(DS2.Colors.text3)
                        TextField("Search ingredients...", text: $searchText)
                            .font(.system(size: 16))
                            .foregroundStyle(DS2.Colors.text1)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(DS2.Colors.text3)
                            }
                        }
                        Button {} label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(DS2.Colors.accent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(DS2.Colors.surface, in: RoundedRectangle(cornerRadius: DS2.r16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS2.r16, style: .continuous)
                            .strokeBorder(DS2.Colors.divider, lineWidth: 1)
                    )

                    // Recent recipes
                    if !recentRecipes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("RECENT")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(DS2.Colors.text3)
                                    .tracking(1.5)
                                Spacer()
                                NavigationLink {
                                    V2RecipeListView(title: "Recent Recipes", recipes: recentRecipes)
                                } label: {
                                    Text("See All")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(DS2.Colors.accent)
                                }
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(recentRecipes) { recipe in
                                        NavigationLink {
                                            V2RecipeDetailView(recipe: recipe)
                                        } label: {
                                            V2MiniRecipeCard(recipe: recipe)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    // Saved recipes
                    if !savedRecipes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("SAVED")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(DS2.Colors.text3)
                                    .tracking(1.5)
                                Spacer()
                                NavigationLink {
                                    V2RecipeListView(title: "Saved Recipes", recipes: savedRecipes)
                                } label: {
                                    Text("See All")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(DS2.Colors.accent)
                                }
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(savedRecipes) { recipe in
                                        NavigationLink {
                                            V2RecipeDetailView(recipe: recipe)
                                        } label: {
                                            V2MiniRecipeCard(recipe: recipe)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    // "Add Your Own" ghost card
                                    Button { showCreateRecipe = true } label: {
                                        V2AddYourOwnCard()
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(V2Data.ingredientCategories) { cat in
                                V2CategoryChip(
                                    name: cat.name,
                                    emoji: cat.emoji,
                                    color: cat.color,
                                    isSelected: selectedCategory == cat.id
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCategory = selectedCategory == cat.id ? nil : cat.id
                                    }
                                }
                            }
                        }
                    }

                    // Ingredient grid
                    VStack(alignment: .leading, spacing: 14) {
                        Text(selectedCategory != nil ? V2Data.ingredientCategories[selectedCategory!].name.uppercased() : "ALL INGREDIENTS")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(DS2.Colors.text3)
                            .tracking(1.5)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                            ForEach(filteredIngredients) { ingredient in
                                V2IngredientBubble(
                                    ingredient: ingredient,
                                    isSelected: selectedIngredients.contains(ingredient)
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        toggleIngredient(ingredient)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }

            // Selected ingredients bar + CTA (appears when ingredients selected)
            // This is empty here since hasIngredients == false triggers state switch
        }
    }

    // ── State 2: Recipe Results ────────────────────────────

    private var resultsState: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Compact header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(greeting) \(timeEmoji)")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(DS2.Colors.text3)
                            Text("Recipes for you")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(DS2.Colors.text1)
                        }
                        Spacer()
                        // Profile avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(colors: [DS2.Colors.accent, DS2.Colors.rose],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 40, height: 40)
                            Text("🧑‍🍳")
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.top, 8)

                    // Selected ingredients strip
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("YOUR INGREDIENTS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(DS2.Colors.text3)
                                .tracking(1.5)
                            Spacer()
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    selectedIngredients.removeAll()
                                    selectedMood = nil
                                }
                            } label: {
                                Text("Edit")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(DS2.Colors.accent)
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedIngredients) { ing in
                                    V2SelectedChip(ingredient: ing) {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedIngredients.removeAll { $0.id == ing.id }
                                        }
                                    }
                                }

                                // Add more button
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        selectedIngredients.removeAll()
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(DS2.Colors.accent)
                                        .frame(width: 34, height: 34)
                                        .background(DS2.Colors.accentSoft, in: Circle())
                                }
                            }
                        }
                    }

                    // Mood filter
                    VStack(alignment: .leading, spacing: 10) {
                        Text("REFINE BY MOOD")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(DS2.Colors.text3)
                            .tracking(1.5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(V2Data.moods) { mood in
                                    MoodPill(mood: mood, isSelected: selectedMood == mood.id)
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                                selectedMood = selectedMood == mood.id ? nil : mood.id
                                            }
                                        }
                                }
                            }
                        }
                    }

                    // Featured recipe
                    if let featured = filteredRecipes.first {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BEST MATCH")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(DS2.Colors.text3)
                                .tracking(1.5)

                            NavigationLink {
                                V2RecipeDetailView(recipe: featured)
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    V2RecipeImage(gradient: featured.gradient, emoji: featured.emoji, height: 240)
                                        .clipShape(RoundedRectangle(cornerRadius: DS2.r24, style: .continuous))

                                    VStack(alignment: .leading, spacing: 6) {
                                        // Match badge
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 11))
                                            Text("\(featured.ingredients.count > 3 ? 83 : 67)% match")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(DS2.Colors.mint.opacity(0.8), in: Capsule())

                                        Text(featured.name)
                                            .font(.system(size: 22, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)

                                        HStack(spacing: 12) {
                                            Label("\(featured.cookTime) min", systemImage: "clock")
                                            Label(featured.difficulty, systemImage: "chart.bar.fill")
                                            StarRating(rating: featured.rating)
                                        }
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.85))
                                    }
                                    .padding(18)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        LinearGradient(
                                            stops: [
                                                .init(color: .black.opacity(0.8), location: 0),
                                                .init(color: .black.opacity(0.3), location: 0.6),
                                                .init(color: .clear, location: 1),
                                            ],
                                            startPoint: .bottom, endPoint: .top
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: DS2.r24, style: .continuous))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // More recipes
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("MORE RECIPES")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(DS2.Colors.text3)
                                .tracking(1.5)
                            Spacer()
                            Text("\(filteredRecipes.count) found")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(DS2.Colors.text2)
                        }

                        ForEach(filteredRecipes.dropFirst()) { recipe in
                            NavigationLink {
                                V2RecipeDetailView(recipe: recipe)
                            } label: {
                                V2RecipeRow(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // ── Helpers ────────────────────────────────────────────

    private func toggleIngredient(_ ingredient: V2Ingredient) {
        if let idx = selectedIngredients.firstIndex(of: ingredient) {
            selectedIngredients.remove(at: idx)
        } else {
            selectedIngredients.append(ingredient)
        }
    }
}

// ── Ingredient Selection Components ───────────────────────

private struct V2CategoryChip: View {
    let name: String
    let emoji: String
    let color: Color
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text(emoji)
                .font(.system(size: 14))
            Text(name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : DS2.Colors.text2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(isSelected ? AnyShapeStyle(color) : AnyShapeStyle(DS2.Colors.surface))
        )
        .overlay(
            Capsule().strokeBorder(isSelected ? Color.clear : DS2.Colors.divider, lineWidth: 1)
        )
    }
}

private struct V2IngredientBubble: View {
    let ingredient: V2Ingredient
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isSelected ? DS2.Colors.accentSoft : DS2.Colors.surface)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle().strokeBorder(isSelected ? DS2.Colors.accent : DS2.Colors.divider, lineWidth: isSelected ? 2 : 1)
                    )
                Text(ingredient.emoji)
                    .font(.system(size: 26))
            }
            .scaleEffect(isSelected ? 1.08 : 1.0)

            Text(ingredient.name)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? DS2.Colors.accent : DS2.Colors.text2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct V2SelectedChip: View {
    let ingredient: V2Ingredient
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text(ingredient.emoji)
                .font(.system(size: 13))
            Text(ingredient.name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(DS2.Colors.text1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS2.Colors.text3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DS2.Colors.surface, in: Capsule())
        .overlay(
            Capsule().strokeBorder(DS2.Colors.divider, lineWidth: 1)
        )
    }
}

// Horizontal recipe row
private struct V2RecipeRow: View {
    let recipe: V2Recipe

    var body: some View {
        HStack(spacing: 14) {
            V2RecipeImage(gradient: recipe.gradient, emoji: recipe.emoji, height: 80)
                .frame(width: 80)
                .clipShape(RoundedRectangle(cornerRadius: DS2.r16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(DS2.Colors.text1)
                    .lineLimit(1)

                Text(recipe.tagline)
                    .font(.system(size: 13))
                    .foregroundStyle(DS2.Colors.text2)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Label("\(recipe.cookTime)m", systemImage: "clock")
                    Label("\(recipe.calories) cal", systemImage: "flame")
                    StarRating(rating: recipe.rating)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(DS2.Colors.text3)
            }

            Spacer()

            Image(systemName: recipe.isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(recipe.isSaved ? DS2.Colors.accent : DS2.Colors.text3)
        }
        .padding(12)
        .frostCard(cornerRadius: DS2.r16)
    }
}

// Mini recipe card for horizontal scroll (Recent / Saved)
private struct V2MiniRecipeCard: View {
    let recipe: V2Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            V2RecipeImage(gradient: recipe.gradient, emoji: recipe.emoji, height: 100)
                .frame(width: 140)

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DS2.Colors.text1)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("\(recipe.cookTime)m")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(DS2.Colors.text3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 140)
        .clipShape(RoundedRectangle(cornerRadius: DS2.r16, style: .continuous))
        .frostCard(cornerRadius: DS2.r16)
    }
}

// "+" Create card for Journey's My Recipes section
private struct V2CreateRecipeCard: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                LinearGradient(
                    colors: [DS2.Colors.accent.opacity(0.25), DS2.Colors.accent.opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: 100)

                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DS2.Colors.accent)
                    .neonGlow(DS2.Colors.accent, radius: 6)
            }

            VStack(spacing: 2) {
                Text("Add Recipe")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DS2.Colors.text1)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 140)
        .clipShape(RoundedRectangle(cornerRadius: DS2.r16, style: .continuous))
        .frostCard(cornerRadius: DS2.r16)
    }
}

// Ghost "+" card for Discover's Saved section
private struct V2AddYourOwnCard: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                DS2.Colors.surface
                    .frame(height: 100)

                VStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(DS2.Colors.accent)
                    Text("Add Your Own")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(DS2.Colors.text3)
                }
            }
        }
        .frame(width: 140, height: 148)
        .clipShape(RoundedRectangle(cornerRadius: DS2.r16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS2.r16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(DS2.Colors.divider)
        )
    }
}

// Mini recipe card with pencil badge for user-created recipes
private struct V2UserMiniRecipeCard: View {
    let recipe: V2Recipe

    var body: some View {
        ZStack(alignment: .topTrailing) {
            V2MiniRecipeCard(recipe: recipe)

            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(DS2.Colors.accent)
                .background(DS2.Colors.card, in: Circle())
                .offset(x: -6, y: 6)
        }
    }
}

// Full recipe list (See All destination)
fileprivate struct V2RecipeListView: View {
    let title: String
    let recipes: [V2Recipe]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(recipes) { recipe in
                    NavigationLink {
                        V2RecipeDetailView(recipe: recipe)
                    } label: {
                        V2RecipeRow(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(DS2.Colors.bg)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// ════════════════════════════════════════════════════════════
// MARK: - 2. Recipe Detail V2
// ════════════════════════════════════════════════════════════

fileprivate struct V2RecipeDetailView: View {
    let recipe: V2Recipe
    @State var isSaved: Bool
    @State var showCookMode = false
    @Environment(\.dismiss) var dismiss

    init(recipe: V2Recipe) {
        self.recipe = recipe
        _isSaved = State(initialValue: recipe.isSaved)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero
                    ZStack(alignment: .top) {
                        V2RecipeImage(gradient: recipe.gradient, emoji: recipe.emoji, height: 340)

                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            Spacer()
                            Button { withAnimation(.spring(response: 0.3)) { isSaved.toggle() } } label: {
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(isSaved ? DS2.Colors.accent : .white)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 56)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 24) {
                        // Title block
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(recipe.name)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(DS2.Colors.text1)
                                Spacer()
                            }
                            Text(recipe.tagline)
                                .font(.system(size: 15))
                                .foregroundStyle(DS2.Colors.text2)
                            HStack(spacing: 8) {
                                StarRating(rating: recipe.rating)
                                Text(String(format: "%.1f", recipe.rating))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(DS2.Colors.gold)
                                Text("by \(recipe.author)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(DS2.Colors.text3)
                            }
                        }

                        // Stats row
                        HStack(spacing: 0) {
                            V2StatPill(icon: "clock", value: "\(recipe.cookTime)m", label: "Time", color: DS2.Colors.accent)
                            V2StatPill(icon: "person.2", value: "\(recipe.servings)", label: "Serve", color: DS2.Colors.mint)
                            V2StatPill(icon: "flame", value: "\(recipe.calories)", label: "Cal", color: DS2.Colors.rose)
                            V2StatPill(icon: "chart.bar.fill", value: recipe.difficulty, label: "Level", color: DS2.Colors.lavender)
                        }
                        .padding(4)
                        .frostCard()

                        // Ingredients
                        VStack(alignment: .leading, spacing: 14) {
                            Text("INGREDIENTS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(DS2.Colors.text3)
                                .tracking(1.5)

                            VStack(spacing: 0) {
                                ForEach(recipe.ingredients.indices, id: \.self) { i in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(DS2.Colors.accent.opacity(0.2))
                                            .frame(width: 8, height: 8)
                                        Text(recipe.ingredients[i])
                                            .font(.system(size: 15))
                                            .foregroundStyle(DS2.Colors.text1)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)

                                    if i < recipe.ingredients.count - 1 {
                                        Divider()
                                            .background(DS2.Colors.divider)
                                            .padding(.leading, 34)
                                    }
                                }
                            }
                            .frostCard(cornerRadius: DS2.r16)
                        }

                        // Steps
                        VStack(alignment: .leading, spacing: 14) {
                            Text("STEPS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(DS2.Colors.text3)
                                .tracking(1.5)

                            VStack(spacing: 12) {
                                ForEach(recipe.steps) { step in
                                    HStack(alignment: .top, spacing: 14) {
                                        Text("\(step.id + 1)")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .frame(width: 28, height: 28)
                                            .background(
                                                LinearGradient(colors: recipe.gradient,
                                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                                in: Circle()
                                            )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(step.text)
                                                .font(.system(size: 15))
                                                .foregroundStyle(DS2.Colors.text1)
                                                .fixedSize(horizontal: false, vertical: true)

                                            if let timer = step.timerMinutes {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "timer")
                                                        .font(.system(size: 11))
                                                    Text("\(timer) min")
                                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                }
                                                .foregroundStyle(DS2.Colors.accent)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(DS2.Colors.accentSoft, in: Capsule())
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(14)
                                    .frostCard(cornerRadius: DS2.r16)
                                }
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(24)
                    .background(DS2.Colors.bg)
                    .clipShape(.rect(topLeadingRadius: DS2.r32, topTrailingRadius: DS2.r32))
                    .offset(y: -32)
                }
            }

            // Start cooking button
            Button { showCookMode = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Start Cooking")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(colors: recipe.gradient, startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: DS2.r16, style: .continuous)
                )
                .neonGlow(recipe.gradient.first ?? DS2.Colors.accent, radius: 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .background(
                LinearGradient(colors: [DS2.Colors.bg, DS2.Colors.bg.opacity(0)],
                               startPoint: .bottom, endPoint: .top)
                .frame(height: 100)
                .allowsHitTesting(false)
            , alignment: .bottom)
            .fullScreenCover(isPresented: $showCookMode) {
                V2CookModeView(recipe: recipe)
            }
        }
        .background(DS2.Colors.bg)
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
    }
}

private struct V2StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DS2.Colors.text1)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(DS2.Colors.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// ════════════════════════════════════════════════════════════
// MARK: - 3. Cook Mode (Hands-Free)
// ════════════════════════════════════════════════════════════

fileprivate struct V2CookModeView: View {
    let recipe: V2Recipe
    @State private var currentStep = 0
    @State private var timerSeconds: Int = 0
    @State private var timerRunning = false
    @State private var completedSteps: Set<Int> = []
    @Environment(\.dismiss) private var dismiss

    private var progress: Double {
        guard !recipe.steps.isEmpty else { return 0 }
        return Double(completedSteps.count) / Double(recipe.steps.count)
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [recipe.gradient.first?.opacity(0.3) ?? DS2.Colors.accent.opacity(0.3), DS2.Colors.bg],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(DS2.Colors.text2)
                            .frame(width: 40, height: 40)
                            .background(DS2.Colors.surface, in: Circle())
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(recipe.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(DS2.Colors.text1)
                        Text("Step \(currentStep + 1) of \(recipe.steps.count)")
                            .font(.system(size: 12))
                            .foregroundStyle(DS2.Colors.text2)
                    }

                    Spacer()

                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(DS2.Colors.surface, lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(DS2.Colors.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(completedSteps.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(DS2.Colors.accent)
                    }
                    .frame(width: 40, height: 40)
                    .animation(.easeInOut, value: progress)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Step progress dots
                HStack(spacing: 6) {
                    ForEach(recipe.steps.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == currentStep ? DS2.Colors.accent :
                                    (completedSteps.contains(i) ? DS2.Colors.mint : DS2.Colors.surfaceLight))
                            .frame(height: 4)
                            .frame(maxWidth: i == currentStep ? .infinity : 16)
                            .animation(.spring(response: 0.35), value: currentStep)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                Spacer()

                // Current step (large, hands-free text)
                VStack(spacing: 24) {
                    Text(recipe.steps[currentStep].text)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DS2.Colors.text1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .id(currentStep) // force transition
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                    // Timer (if step has one)
                    if let timerMin = recipe.steps[currentStep].timerMinutes {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(DS2.Colors.surface, lineWidth: 6)
                                    .frame(width: 120, height: 120)

                                Circle()
                                    .trim(from: 0, to: timerRunning ? CGFloat(timerSeconds) / CGFloat(timerMin * 60) : 0)
                                    .stroke(DS2.Colors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90))

                                VStack(spacing: 2) {
                                    Text(timerRunning ? formatTime(timerMin * 60 - timerSeconds) : formatTime(timerMin * 60))
                                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                                        .foregroundStyle(DS2.Colors.text1)
                                    Text("minutes")
                                        .font(.system(size: 11))
                                        .foregroundStyle(DS2.Colors.text3)
                                }
                            }

                            Button {
                                timerRunning.toggle()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: timerRunning ? "pause.fill" : "play.fill")
                                    Text(timerRunning ? "Pause" : "Start Timer")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(DS2.Colors.accent)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(DS2.Colors.accentSoft, in: Capsule())
                            }
                        }
                    }
                }

                Spacer()

                // Navigation buttons
                HStack(spacing: 16) {
                    // Previous
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if currentStep > 0 {
                                currentStep -= 1
                                timerRunning = false
                                timerSeconds = 0
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(currentStep > 0 ? DS2.Colors.text1 : DS2.Colors.text3)
                            .frame(width: 56, height: 56)
                            .background(DS2.Colors.surface, in: Circle())
                    }
                    .disabled(currentStep == 0)

                    // Done / Mark complete
                    Button {
                        withAnimation(.spring(response: 0.35)) {
                            completedSteps.insert(currentStep)
                            if currentStep < recipe.steps.count - 1 {
                                currentStep += 1
                                timerRunning = false
                                timerSeconds = 0
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: completedSteps.contains(currentStep) ? "checkmark.circle.fill" : "checkmark")
                                .font(.system(size: 18, weight: .bold))
                            Text(currentStep == recipe.steps.count - 1 ? "Finish" : "Done")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(colors: recipe.gradient, startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .neonGlow(recipe.gradient.first ?? DS2.Colors.accent, radius: 8)
                    }

                    // Next
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if currentStep < recipe.steps.count - 1 {
                                currentStep += 1
                                timerRunning = false
                                timerSeconds = 0
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(currentStep < recipe.steps.count - 1 ? DS2.Colors.text1 : DS2.Colors.text3)
                            .frame(width: 56, height: 56)
                            .background(DS2.Colors.surface, in: Circle())
                    }
                    .disabled(currentStep >= recipe.steps.count - 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// ════════════════════════════════════════════════════════════
// MARK: - 4. Journey (Profile + Stats + Achievements)
// ════════════════════════════════════════════════════════════

fileprivate struct V2JourneyView: View {
    @State private var showCreateRecipe = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Profile header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [DS2.Colors.accent, DS2.Colors.rose],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 80, height: 80)
                        Text("🧑‍🍳")
                            .font(.system(size: 40))
                    }
                    .neonGlow(DS2.Colors.accent, radius: 10)

                    VStack(spacing: 4) {
                        Text("Home Chef")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(DS2.Colors.text1)
                        Text("Cooking since January 2026")
                            .font(.system(size: 14))
                            .foregroundStyle(DS2.Colors.text2)
                    }

                    // Level badge
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DS2.Colors.gold)
                        Text("Level 7 • Sous Chef")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(DS2.Colors.gold)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(DS2.Colors.gold.opacity(0.12), in: Capsule())
                }
                .padding(.top, 8)

                // Stats grid
                HStack(spacing: 12) {
                    V2JourneyStat(value: "42", label: "Recipes\nCooked", icon: "fork.knife", color: DS2.Colors.accent)
                    V2JourneyStat(value: "5", label: "Day\nStreak", icon: "flame.fill", color: DS2.Colors.rose)
                    V2JourneyStat(value: "12", label: "Hours\nCooking", icon: "clock", color: DS2.Colors.mint)
                }

                // My Recipes
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("MY RECIPES")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(DS2.Colors.text3)
                            .tracking(1.5)
                        Spacer()
                        Text("\(V2Data.userRecipes.count) recipes")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(DS2.Colors.text3)
                        NavigationLink {
                            V2RecipeListView(title: "My Recipes", recipes: V2Data.userRecipes)
                        } label: {
                            Text("See All")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(DS2.Colors.accent)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // "+ Create" card
                            Button { showCreateRecipe = true } label: {
                                V2CreateRecipeCard()
                            }
                            .buttonStyle(.plain)

                            ForEach(V2Data.userRecipes) { recipe in
                                NavigationLink {
                                    V2RecipeDetailView(recipe: recipe)
                                } label: {
                                    V2UserMiniRecipeCard(recipe: recipe)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Weekly activity
                VStack(alignment: .leading, spacing: 14) {
                    Text("THIS WEEK")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(DS2.Colors.text3)
                        .tracking(1.5)

                    HStack(spacing: 8) {
                        ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                            VStack(spacing: 8) {
                                let isActive = ["M", "T", "W", "T", "F"].contains(day) && day != "F"
                                let isToday = day == "T" // just for mock
                                Circle()
                                    .fill(isActive ? DS2.Colors.accent : DS2.Colors.surface)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Group {
                                            if isActive {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(isToday ? DS2.Colors.accent : .clear, lineWidth: 2)
                                            .frame(width: 42, height: 42)
                                    )

                                Text(day)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(isToday ? DS2.Colors.accent : DS2.Colors.text3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(16)
                    .frostCard()
                }

                // Achievements
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("ACHIEVEMENTS")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(DS2.Colors.text3)
                            .tracking(1.5)
                        Spacer()
                        Text("1/5")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS2.Colors.text2)
                    }

                    VStack(spacing: 10) {
                        ForEach(V2Data.achievements) { ach in
                            V2AchievementRow(achievement: ach)
                        }
                    }
                }

                // Cooking history
                VStack(alignment: .leading, spacing: 14) {
                    Text("RECENT ACTIVITY")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(DS2.Colors.text3)
                        .tracking(1.5)

                    VStack(spacing: 0) {
                        ForEach(V2Data.recipes.prefix(3)) { recipe in
                            HStack(spacing: 12) {
                                V2RecipeImage(gradient: recipe.gradient, emoji: recipe.emoji, height: 50)
                                    .frame(width: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: DS2.r12, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(recipe.name)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(DS2.Colors.text1)
                                    Text("Cooked 2 days ago")
                                        .font(.system(size: 11))
                                        .foregroundStyle(DS2.Colors.text3)
                                }
                                Spacer()
                                StarRating(rating: recipe.rating)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)

                            if recipe.id < 2 {
                                Divider()
                                    .background(DS2.Colors.divider)
                                    .padding(.leading, 76)
                            }
                        }
                    }
                    .frostCard(cornerRadius: DS2.r16)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
        .background(DS2.Colors.bg)
        .sheet(isPresented: $showCreateRecipe) {
            V2CreateRecipeView()
        }
    }
}

private struct V2JourneyStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(DS2.Colors.text1)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(DS2.Colors.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .frostCard()
    }
}

private struct V2AchievementRow: View {
    let achievement: V2Achievement

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.color.opacity(0.2) : DS2.Colors.surface)
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(achievement.isUnlocked ? achievement.color : DS2.Colors.text3)
            }
            .neonGlow(achievement.isUnlocked ? achievement.color : .clear, radius: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(achievement.isUnlocked ? DS2.Colors.text1 : DS2.Colors.text2)

                Text(achievement.description)
                    .font(.system(size: 12))
                    .foregroundStyle(DS2.Colors.text3)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DS2.Colors.surface)
                            .frame(height: 4)
                        Capsule()
                            .fill(achievement.color)
                            .frame(width: geo.size.width * achievement.progress, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Text("\(Int(achievement.progress * 100))%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(achievement.color)
        }
        .padding(14)
        .frostCard(cornerRadius: DS2.r16)
    }
}

// ════════════════════════════════════════════════════════════
// MARK: - 5. Create Recipe (Sheet)
// ════════════════════════════════════════════════════════════

fileprivate struct V2CreateRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var recipeName = ""
    @State private var tagline = ""
    @State private var selectedEmoji = "🍲"
    @State private var ingredients: [String] = ["", ""]
    @State private var steps: [String] = [""]
    @State private var cookTime = 20
    @State private var servings = 2
    @State private var selectedDifficulty = "Easy"

    private let totalSteps = 5
    private let emojiOptions = ["🍲", "🥗", "🍳", "🍝", "🌮", "🍜", "🥘", "🍛", "🥤", "🍰", "🥪", "🍕"]
    private let cookTimeOptions = [5, 10, 15, 20, 30, 45, 60, 90]
    private let difficulties = [
        ("Easy", DS2.Colors.mint),
        ("Medium", DS2.Colors.accent),
        ("Hard", DS2.Colors.rose)
    ]

    private var stepTitles: [String] {
        ["Name Your Recipe", "Add Ingredients", "Add Steps", "Details", "Review & Save"]
    }

    var body: some View {
        ZStack {
            DS2.Colors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                sheetHeader

                // Step progress dots
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i == currentStep ? DS2.Colors.accent :
                                    (i < currentStep ? DS2.Colors.mint : DS2.Colors.surfaceLight))
                            .frame(height: 4)
                            .frame(maxWidth: i == currentStep ? .infinity : 16)
                            .animation(.spring(response: 0.35), value: currentStep)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Step content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch currentStep {
                        case 0: step1NameAndPhoto
                        case 1: step2Ingredients
                        case 2: step3Steps
                        case 3: step4Details
                        case 4: step5Review
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 100)
                }

                // Bottom button
                bottomButton
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Button {
                if currentStep == 0 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.35)) { currentStep -= 1 }
                }
            } label: {
                if currentStep == 0 {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS2.Colors.text2)
                        .frame(width: 36, height: 36)
                        .background(DS2.Colors.surface, in: Circle())
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Back")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(DS2.Colors.accent)
                }
            }

            Spacer()

            Text(stepTitles[currentStep])
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(DS2.Colors.text1)

            Spacer()

            // Invisible balance element
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Step 1: Name & Photo

    private var step1NameAndPhoto: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Emoji preview
            ZStack {
                LinearGradient(
                    colors: [DS2.Colors.accent.opacity(0.5), DS2.Colors.rose.opacity(0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Text(selectedEmoji)
                    .font(.system(size: 64))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: DS2.r24, style: .continuous))

            // Name
            VStack(alignment: .leading, spacing: 8) {
                Text("RECIPE NAME")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(DS2.Colors.text3)
                    .tracking(1.5)

                TextField("Recipe name", text: $recipeName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(DS2.Colors.text1)
                    .padding(16)
                    .background(DS2.Colors.surface, in: RoundedRectangle(cornerRadius: DS2.r16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS2.r16, style: .continuous)
                            .strokeBorder(DS2.Colors.divider, lineWidth: 1)
                    )
            }

            // Tagline
            VStack(alignment: .leading, spacing: 8) {
                Text("TAGLINE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(DS2.Colors.text3)
                    .tracking(1.5)

                TextField("Short description", text: $tagline)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(DS2.Colors.text1)
                    .padding(16)
                    .background(DS2.Colors.surface, in: RoundedRectangle(cornerRadius: DS2.r16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS2.r16, style: .continuous)
                            .strokeBorder(DS2.Colors.divider, lineWidth: 1)
                    )
            }

            // Emoji picker
            VStack(alignment: .leading, spacing: 8) {
                Text("CHOOSE AN ICON")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(DS2.Colors.text3)
                    .tracking(1.5)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(selectedEmoji == emoji ? DS2.Colors.accentSoft : DS2.Colors.surface)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(selectedEmoji == emoji ? DS2.Colors.accent : DS2.Colors.divider, lineWidth: selectedEmoji == emoji ? 2 : 1)
                            )
                            .scaleEffect(selectedEmoji == emoji ? 1.1 : 1.0)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) { selectedEmoji = emoji }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Ingredients

    private var step2Ingredients: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("INGREDIENTS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(DS2.Colors.text3)
                .tracking(1.5)

            VStack(spacing: 10) {
                ForEach(ingredients.indices, id: \.self) { i in
                    HStack(spacing: 10) {
                        Button {
                            if ingredients.count > 1 {
                                withAnimation(.spring(response: 0.3)) {
                                    ingredients.remove(at: i)
                                }
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(DS2.Colors.rose.opacity(ingredients.count > 1 ? 1 : 0.3))
                        }
                        .disabled(ingredients.count <= 1)

                        TextField("Ingredient \(i + 1)", text: $ingredients[i])
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(DS2.Colors.text1)
                            .padding(14)
                            .background(DS2.Colors.surface, in: RoundedRectangle(cornerRadius: DS2.r12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS2.r12, style: .continuous)
                                    .strokeBorder(DS2.Colors.divider, lineWidth: 1)
                            )
                    }
                }
            }

            Button {
                withAnimation(.spring(response: 0.3)) {
                    ingredients.append("")
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Add Ingredient")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(DS2.Colors.accent)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(DS2.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS2.r12, style: .continuous))
            }
        }
    }

    // MARK: - Step 3: Steps

    private var step3Steps: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("COOKING STEPS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(DS2.Colors.text3)
                .tracking(1.5)

            step3StepsList
            step3AddStepButton
        }
    }

    @ViewBuilder
    private var step3StepsList: some View {
        VStack(spacing: 12) {
            ForEach(Array(steps.indices), id: \.self) { (i: Int) in
                step3StepRow(index: i)
            }
        }
    }

    private func step3StepRow(index i: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(i + 1)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    LinearGradient(colors: [DS2.Colors.accent, DS2.Colors.rose],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .padding(.top, 10)

            TextField("Step \(i + 1)", text: $steps[i], axis: .vertical)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(DS2.Colors.text1)
                .lineLimit(3...6)
                .padding(14)
                .background(DS2.Colors.surface, in: RoundedRectangle(cornerRadius: DS2.r12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS2.r12, style: .continuous)
                        .strokeBorder(DS2.Colors.divider, lineWidth: 1)
                )

            if steps.count > 1 {
                Button {
                    let idx = i
                    withAnimation(.spring(response: 0.3)) {
                        _ = steps.remove(at: idx)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(DS2.Colors.text3)
                }
                .padding(.top, 14)
            }
        }
    }

    private var step3AddStepButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                steps.append("")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("Add Step")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(DS2.Colors.accent)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(DS2.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS2.r12, style: .continuous))
        }
    }

    // MARK: - Step 4: Details

    private var step4Details: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Cook time
            VStack(alignment: .leading, spacing: 10) {
                Text("COOK TIME")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(DS2.Colors.text3)
                    .tracking(1.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(cookTimeOptions, id: \.self) { time in
                            Text("\(time)m")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(cookTime == time ? .white : DS2.Colors.text2)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(cookTime == time ? DS2.Colors.accent : DS2.Colors.surface)
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(cookTime == time ? Color.clear : DS2.Colors.divider, lineWidth: 1)
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) { cookTime = time }
                                }
                        }
                    }
                }
            }

            // Servings
            VStack(alignment: .leading, spacing: 10) {
                Text("SERVINGS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(DS2.Colors.text3)
                    .tracking(1.5)

                HStack(spacing: 20) {
                    Button {
                        if servings > 1 { withAnimation { servings -= 1 } }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(servings > 1 ? DS2.Colors.text1 : DS2.Colors.text3)
                            .frame(width: 44, height: 44)
                            .background(DS2.Colors.surface, in: Circle())
                    }

                    Text("\(servings)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DS2.Colors.text1)
                        .frame(width: 50)

                    Button {
                        if servings < 12 { withAnimation { servings += 1 } }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(servings < 12 ? DS2.Colors.text1 : DS2.Colors.text3)
                            .frame(width: 44, height: 44)
                            .background(DS2.Colors.surface, in: Circle())
                    }
                }
                .padding(16)
                .frostCard(cornerRadius: DS2.r16)
            }

            // Difficulty
            VStack(alignment: .leading, spacing: 10) {
                Text("DIFFICULTY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(DS2.Colors.text3)
                    .tracking(1.5)

                HStack(spacing: 10) {
                    ForEach(difficulties, id: \.0) { diff, color in
                        Text(diff)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(selectedDifficulty == diff ? .white : color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: DS2.r12, style: .continuous)
                                    .fill(selectedDifficulty == diff ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.12)))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DS2.r12, style: .continuous)
                                    .strokeBorder(selectedDifficulty == diff ? Color.clear : color.opacity(0.3), lineWidth: 1)
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedDifficulty = diff }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Step 5: Review

    private var step5Review: some View {
        VStack(spacing: 20) {
            // Preview card
            VStack(spacing: 0) {
                // Emoji hero
                ZStack {
                    LinearGradient(
                        colors: [DS2.Colors.accent.opacity(0.5), DS2.Colors.rose.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Text(selectedEmoji)
                        .font(.system(size: 56))
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(.rect(topLeadingRadius: DS2.r20, topTrailingRadius: DS2.r20))

                VStack(alignment: .leading, spacing: 12) {
                    Text(recipeName.isEmpty ? "Untitled Recipe" : recipeName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(DS2.Colors.text1)

                    if !tagline.isEmpty {
                        Text(tagline)
                            .font(.system(size: 14))
                            .foregroundStyle(DS2.Colors.text2)
                    }

                    // Stats
                    HStack(spacing: 0) {
                        V2StatPill(icon: "clock", value: "\(cookTime)m", label: "Time", color: DS2.Colors.accent)
                        V2StatPill(icon: "person.2", value: "\(servings)", label: "Serve", color: DS2.Colors.mint)
                        V2StatPill(icon: "chart.bar.fill", value: selectedDifficulty, label: "Level", color: DS2.Colors.lavender)
                    }
                    .padding(4)
                    .frostCard()

                    // Counts
                    HStack(spacing: 16) {
                        Label("\(ingredients.filter { !$0.isEmpty }.count) ingredients", systemImage: "list.bullet")
                        Label("\(steps.filter { !$0.isEmpty }.count) steps", systemImage: "number")
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(DS2.Colors.text3)
                }
                .padding(18)
            }
            .frostCard(cornerRadius: DS2.r20)
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [DS2.Colors.bg, DS2.Colors.bg.opacity(0)],
                           startPoint: .bottom, endPoint: .top)
                .frame(height: 30)
                .allowsHitTesting(false)

            Button {
                if currentStep < totalSteps - 1 {
                    withAnimation(.spring(response: 0.35)) { currentStep += 1 }
                } else {
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    if currentStep == totalSteps - 1 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(currentStep == totalSteps - 1 ? "Save Recipe" : "Next")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(colors: [DS2.Colors.accent, DS2.Colors.rose],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: DS2.r16, style: .continuous)
                )
                .neonGlow(DS2.Colors.accent, radius: 10)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(DS2.Colors.bg)
    }
}

// ════════════════════════════════════════════════════════════
// MARK: - Root Container V2
// ════════════════════════════════════════════════════════════

struct V2MockAppContainer: View {
    var body: some View {
        TabView {
            NavigationStack {
                V2DiscoverView()
            }
            .tabItem {
                Label("Discover", systemImage: "compass.drawing")
            }

            NavigationStack {
                V2JourneyView()
            }
            .tabItem {
                Label("Journey", systemImage: "trophy.fill")
            }
        }
        .tint(DS2.Colors.accent)
    }
}

// ════════════════════════════════════════════════════════════
// MARK: - Previews
// ════════════════════════════════════════════════════════════

#Preview("V2 — Full App") {
    V2MockAppContainer()
        .preferredColorScheme(.dark)
}

#Preview("V2 — Discover") {
    NavigationStack {
        V2DiscoverView()
    }
    .preferredColorScheme(.dark)
}

#Preview("V2 — Recipe Detail") {
    V2RecipeDetailView(recipe: V2Data.recipes[0])
        .preferredColorScheme(.dark)
}

#Preview("V2 — Cook Mode") {
    V2CookModeView(recipe: V2Data.recipes[2])
        .preferredColorScheme(.dark)
}

#Preview("V2 — Journey") {
    NavigationStack {
        V2JourneyView()
    }
    .preferredColorScheme(.dark)
}

#Preview("V2 — Create Recipe") {
    V2CreateRecipeView()
        .preferredColorScheme(.dark)
}
