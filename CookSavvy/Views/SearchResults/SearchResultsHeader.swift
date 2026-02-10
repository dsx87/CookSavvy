//
//  SearchResultsHeader.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 03/07/2025.
//

import SwiftUI

struct SearchResultsHeader: View {
    let count: Int
    let ingredients: Set<Ingredient>
    
    var body: some View {
        VStack(alignment:.leading) {
            Text(String(format: Strings.SearchResults.foundFormat, count, ingredients.asSmallString))
                .font(.caption)
        }
    }
}

extension Set where Element == Ingredient {
    var asSmallString: String {
        if count > UI.SearchResults.ingredientLimit {
            prefix(UI.SearchResults.ingredientLimit).map(\.name).joined(separator: ",") + "..."
        } else {
            map(\.name).joined(separator: ",")
        }
    }
}

#Preview {
    SearchResultsHeader(count: 4, ingredients: [.empty])
}
