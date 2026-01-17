//
//  RecipeDetailsView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

struct RecipeDetailsView: View {
    @ObservedObject var viewModel: RecipeDetailsViewModel

    var body: some View {
        VStack(alignment: .leading) {
            AsyncImageDisk(imageName: viewModel.recipe.image) {
                DefaultPlaceholder()
            }
            .frame(maxHeight: 250)
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
                        Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundColor(viewModel.isFavorite ? .red : .gray)
                    }
                    .disabled(viewModel.isLoadingFavorite)
                }
                RecipeDetailsAdditionalInfo(info: viewModel.recipe.additionalInfo)
                RecipeDetailsList(
                    title: "🛒 Ingredients",
                    items: viewModel.recipe.ingredients.map { "• " + $0.name }
                )
                RecipeDetailsList(
                    title: "🧑‍🍳 Instructions",
                    items: viewModel.recipe.instructions.map { "• " + $0 }
                )
            }
            .padding(.horizontal)
        }

        .background {
            Color.lightGrayBack
                .ignoresSafeArea()
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
        (title:self.asEmoji + " " + self.title, value: stringValue)
    }
    
    var isNotEmpty: Bool {
        self != .empty
    }
}
