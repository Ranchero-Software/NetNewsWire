//
//  SizeCategories.swift
//  NetNewsWire iOS Widget Extension
//
//  Created by Stuart Breckenridge on 24/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI

struct SizeCategories {
	
	let largeSizeCategories: [ContentSizeCategory] = [.extraExtraLarge,
													  .extraExtraExtraLarge,
													  .accessibilityMedium,
													  .accessibilityLarge,
													  .accessibilityExtraLarge,
													  .accessibilityExtraExtraLarge,
													  .accessibilityExtraExtraExtraLarge]
	
	
	func isSizeCategoryLarge(category: ContentSizeCategory) -> Bool {
		largeSizeCategories.filter{ $0 == category }.count == 1
	}
	
}
