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
        guard info.infos.count < 4 else {
            return info.infos
        }
        
        let numberOfMissingInfos = 4 - info.infos.count
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
            RoundedRectangle(cornerRadius: 10)
                .foregroundStyle(Color.white)
                .shadow(radius: 0.2, x: 0.2, y: 0.2)
                .frame(maxWidth: .infinity, maxHeight: 50)
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
