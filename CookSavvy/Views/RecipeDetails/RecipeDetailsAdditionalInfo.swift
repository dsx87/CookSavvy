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
        guard info.infos.count < UI.RecipeDetails.additionalInfoSlotsCount else {
            return info.infos
        }
        
        let numberOfMissingInfos = UI.RecipeDetails.additionalInfoSlotsCount - info.infos.count
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
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UI.RecipeDetails.cardCornerRadius)
                .foregroundStyle(theme.card)
                .shadow(color: .black.opacity(0.08), radius: UI.RecipeDetails.cardShadowRadius, x: UI.RecipeDetails.cardShadowOffset, y: UI.RecipeDetails.cardShadowOffset)
                .frame(maxWidth: .infinity, maxHeight: UI.RecipeDetails.additionalInfoCellHeight)
            VStack {
                Text(info.title)
                    .font(.caption)
                    .foregroundStyle(theme.text2)
                Text(info.value)
                    .font(.caption)
                    .foregroundStyle(theme.text1)
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
