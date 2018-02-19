//
//  MarkCommandValidationStatus.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Foundation

enum MarkCommandValidationStatus {

	case canMark, canUnmark, canDoNothing

	static func statusFor(_ articles: ArticleArray, _ canMarkTest: ((ArticleArray) -> Bool)) -> MarkCommandValidationStatus {

		if articles.isEmpty {
			return .canDoNothing
		}
		return canMarkTest(articles) ? .canMark : .canUnmark
	}
}
