//
//  RecipeDetailsView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

struct RecipeDetailsView: View {
    @ObservedObject var viewModel: RecipeDetailsViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                AsyncImageDisk(imageName: viewModel.recipe.image) {
                    DefaultPlaceholder()
                }
                .frame(height: UI.RecipeDetails.imageHeight)
                Group {
                    HStack {
                        Text(viewModel.recipe.title)
                            .font(.title)
                        Spacer()
                        Button(action: {
                            Task {
                                await viewModel.toggleFavorite()
                            }
                        }) {
                            Image(systemName: viewModel.isFavorite ? Icons.RecipeDetails.favoriteFilled : Icons.RecipeDetails.favoriteOutline)
                                .font(.title2)
                                .foregroundColor(viewModel.isFavorite ? .red : .gray)
                        }
                        .disabled(viewModel.isLoadingFavorite)
                    }
                    RecipeDetailsAdditionalInfo(info: viewModel.recipe.additionalInfo)
                    RecipeDetailsList(
                        title: Strings.RecipeDetails.ingredientsTitle,
                        items: viewModel.recipe.ingredients.map { UI.RecipeDetails.bulletPrefix + $0.name }
                    )
                    RecipeDetailsList(
                        title: Strings.RecipeDetails.instructionsTitle,
                        items: viewModel.recipe.instructions.map { UI.RecipeDetails.bulletPrefix + $0 }
                    )
                }
                .padding(.horizontal)
            }
            
            .background {
                theme.backgroundSubtle
                    .ignoresSafeArea()
            }
        }
    }
}


#Preview("RecipeDetailsView") {
    let dbInterface = DBInterface()
    return RecipeDetailsView(
        viewModel: RecipeDetailsViewModel(
            recipe: .init(),
            userDataService: UserDataService(dbInterface: dbInterface)
        )
    )
}



extension Recipe.AdditionalInfo.InfoType {
    var asTuple:(title: String, value: String) {
        (title:self.asEmoji + UI.RecipeDetails.infoTitleSeparator + self.title, value: stringValue)
    }
    
    var isNotEmpty: Bool {
        self != .empty
    }
}
