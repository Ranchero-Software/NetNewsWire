//
//  FeedlyUtilities.swift
//
//
//  Created by Brent Simmons on 5/17/24.
//

import Foundation
import Parser

final class FeedlyUtilities {

	static func parsedItemsKeyedByFeedURL(_ parsedItems: Set<ParsedItem>) -> [String: Set<ParsedItem>] {

		var d = [String: Set<ParsedItem>]()

		for parsedItem in parsedItems {
			let key = parsedItem.feedURL

			let value: Set<ParsedItem> = {
				if var items = d[key] {
					items.insert(parsedItem)
					return items
				} else {
					return [parsedItem]
				}
			}()

			d[key] = value
		}

		return d
	}
}
