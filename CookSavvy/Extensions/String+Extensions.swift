//
//  String+Extensions.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 24/06/2025.
//

import Foundation

/// Convenience parsing helpers used when normalizing CSV-backed text fields.
extension String {
    /// Extracts substrings enclosed in single-quote pairs from the receiver.
    ///
    /// Used to parse the CSV ingredient field format where each ingredient name is
    /// wrapped in single quotes (e.g. `"'garlic','onion','chicken'"`).
    /// An unpaired trailing quote is discarded to prevent out-of-bounds access.
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
    
    /// Returns the first character of the string if it is an emoji, otherwise `nil`.
    var firstCharAsEmoji: Character? {
        guard first?.isEmoji == true else {
            return nil
        }
        
        return first
    }
}
