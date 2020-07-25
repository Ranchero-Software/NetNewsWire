//
//  TimelineItems.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/25/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

struct TimelineItems {
	
	var index = [String: Int]()
	var items = [TimelineItem]()
	
	init() {}
	
	subscript(key: String) -> TimelineItem? {
		get {
			if let position = index[key] {
				return items[position]
			}
			return nil
		}
	}
	
	mutating func append(_ item: TimelineItem) {
		index[item.id] = item.position
		items.append(item)
	}
	
}
