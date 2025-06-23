//
//  String+extensions.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 24/06/2025.
//

import Foundation

extension String {
    var separatedByQuotes: [String] {
        var r = self.ranges(of: "'")
        if r.count % 2 != 0 {
            r.removeLast()
        }
        let res = stride(from: r.startIndex, to: r.endIndex, by: 2).map { idx in
            let start = r[idx]
            let finish = r[idx+1]
            return String(self[start.upperBound..<finish.lowerBound])
        }
        return res
    }
}
