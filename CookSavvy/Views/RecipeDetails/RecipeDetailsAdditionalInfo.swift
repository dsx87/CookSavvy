//
//  RecipeDetailsAdditionalInfo.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 23/07/2025.
//

import SwiftUI

struct RecipeDetailsAdditionalInfo: View {
    let info: Recipe.AdditionalInfo
    private var fixedInfos: [Recipe.AdditionalInfo.InfoType] {
        guard info.infos.count < UIConstants.recipeAdditionalInfoSlotsCount else {
            return info.infos
        }
        
        let numberOfMissingInfos = UIConstants.recipeAdditionalInfoSlotsCount - info.infos.count
        let missingInfos = (0..<numberOfMissingInfos).map { _ in Recipe.AdditionalInfo.InfoType.empty
        }
        
        return info.infos + missingInfos
    }
    var body: some View {
        Grid {
            GridRow {
                if fixedInfos[0].isNotEmpty {
                    RecipeDetailsAdditionalInfoCell(info: (fixedInfos[0].asTuple))
                }
                if fixedInfos[1].isNotEmpty {
                    RecipeDetailsAdditionalInfoCell(info: (fixedInfos[1].asTuple))
                }
            }
            GridRow {
                if fixedInfos[2].isNotEmpty {
                    RecipeDetailsAdditionalInfoCell(info: (fixedInfos[2].asTuple))
                }
                if fixedInfos[3].isNotEmpty {
                    RecipeDetailsAdditionalInfoCell(info: (fixedInfos[3].asTuple))
                }
            }
        }
    }
}

struct RecipeDetailsAdditionalInfoCell: View {
    let info: (title: String, value:String)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UIConstants.recipeDetailsCardCornerRadius)
                .foregroundStyle(Color.white)
                .shadow(radius: UIConstants.recipeDetailsCardShadowRadius, x: UIConstants.recipeDetailsCardShadowOffset, y: UIConstants.recipeDetailsCardShadowOffset)
                .frame(maxWidth: .infinity, maxHeight: UIConstants.recipeDetailsAdditionalInfoCellHeight)
            VStack {
                Text(info.title)
                    .font(.caption)
                Text(info.value)
                    .font(.caption)
            }
        }
    }
}

#Preview("RecipeDetailsAdditionalInfoCell") {
    RecipeDetailsAdditionalInfoCell(info:(title:"Title", value: "Value"))
}

#Preview("RecipeDetailsAdditionalInfo") {
    RecipeDetailsAdditionalInfo(info: .mock)
}
