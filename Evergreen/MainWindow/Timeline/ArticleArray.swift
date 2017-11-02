//
//  ArticleArray.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/1/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Data

extension Array where Element == Article {

	func articleAtRow(_ row: Int) -> Article? {

		if row < 0 || row == NSNotFound || row > count - 1 {
			return nil
		}
		return self[row]
	}

}
