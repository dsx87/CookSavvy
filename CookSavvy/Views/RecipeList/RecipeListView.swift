import SwiftUI

struct RecipeListView: View {
    @Environment(\.appTheme) private var theme
    @StateObject var viewModel: RecipeListViewModel
    var onRecipeTap: ((Recipe) -> Void)?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: UI.RecipeList.stackSpacing) {
                ForEach(viewModel.recipes) { recipe in
                    Button {
                        onRecipeTap?(recipe)
                    } label: {
                        RecipeRow(recipe: recipe, isSaved: viewModel.isSaved(recipe))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, UI.RecipeList.horizontalPadding)
            .padding(.top, UI.RecipeList.topPadding)
        }
        .background(theme.bg)
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadSavedStatus()
        }
    }
}
