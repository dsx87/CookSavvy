//
//  Character+extensions.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/06/2025.
//

import Foundation

/// Emoji-related helpers for single `Character` values.
extension Character {
    /// A simple emoji is one scalar and presented to the user as an Emoji
    fileprivate var isSimpleEmoji: Bool {
        guard let firstScalar = unicodeScalars.first else { return false }
        return firstScalar.properties.isEmoji && firstScalar.value > 0x238C
    }

    /// Checks if the scalars will be merged into an emoji
    fileprivate var isCombinedIntoEmoji: Bool { unicodeScalars.count > 1 && unicodeScalars.first?.properties.isEmoji ?? false }

    /// `true` when the character is rendered as an emoji by the system.
    var isEmoji: Bool { isSimpleEmoji || isCombinedIntoEmoji }
}
