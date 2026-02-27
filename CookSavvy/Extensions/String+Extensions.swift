//
//  String+Extensions.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 24/06/2025.
//

import Foundation

extension String {
    var separatedByQuotes: [String] {
        var quoteRanges = self.ranges(of: "'")
        if quoteRanges.count % 2 != 0 {
            quoteRanges.removeLast()
        }
        let quotedSegments = stride(from: quoteRanges.startIndex, to: quoteRanges.endIndex, by: 2).map { rangeIndex in
            let start = quoteRanges[rangeIndex]
            let finish = quoteRanges[rangeIndex + 1]
            return String(self[start.upperBound..<finish.lowerBound])
        }
        return quotedSegments
    }
    
    var firstCharAsEmoji: Character? {
        guard first?.isEmoji == true else {
            return nil
        }
        
        return first
    }
}
