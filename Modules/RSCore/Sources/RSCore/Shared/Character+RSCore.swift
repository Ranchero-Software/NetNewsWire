//
//  Character+RSCore.swift
//  RSCore
//
//  Created by Maurice Parker on 4/20/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension Character {

	var isSimpleEmoji: Bool {
        guard let firstScalar = unicodeScalars.first else { return false }
        return firstScalar.properties.isEmoji && firstScalar.value > 0x238C
    }

    var isCombinedIntoEmoji: Bool { unicodeScalars.count > 1 && unicodeScalars.first?.properties.isEmoji ?? false }

    var isEmoji: Bool { isSimpleEmoji || isCombinedIntoEmoji }
}
