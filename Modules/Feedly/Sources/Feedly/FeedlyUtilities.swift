//
//  FeedlyUtilities.swift
//
//
//  Created by Brent Simmons on 5/17/24.
//

import Foundation
import Parser

public final class FeedlyUtilities {

	public static func parsedItemsKeyedByFeedURL(_ parsedItems: Set<ParsedItem>) -> [String: Set<ParsedItem>] {

		var d = [String: Set<ParsedItem>]()

		for parsedItem in parsedItems {
			let key = parsedItem.feedURL
			var parsedItems = d[key] ?? Set<ParsedItem>()
			parsedItems.insert(parsedItem)
			d[key] = parsedItems
		}

		return d
	}
}
