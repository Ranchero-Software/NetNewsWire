//
//  SidebarWindowState.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 12/16/23.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import Foundation

class SidebarWindowState: NSObject, NSSecureCoding {
	
	static var supportsSecureCoding = true
	
	let isReadFiltered: Bool
	let expandedContainers: [[String: String]]
	let selectedFeeds: [[String: String]]
	
	init(isReadFiltered: Bool, expandedContainers: [[String : String]], selectedFeeds: [[String : String]]) {
		self.isReadFiltered = isReadFiltered
		self.expandedContainers = expandedContainers
		self.selectedFeeds = selectedFeeds
	}
	
	required init?(coder: NSCoder) {
		isReadFiltered = coder.decodeBool(forKey: "isReadFiltered")
		expandedContainers = coder.decodeObject(of: [NSArray.self, NSDictionary.self, NSString.self], forKey: "expandedContainers") as? [[String: String]] ?? []
		selectedFeeds = coder.decodeObject(of: [NSArray.self, NSDictionary.self, NSString.self], forKey: "selectedFeeds") as? [[String: String]] ?? []
	}
	
	func encode(with coder: NSCoder) {
		coder.encode(isReadFiltered, forKey: "isReadFiltered")
		coder.encode(expandedContainers, forKey: "expandedContainers")
		coder.encode(selectedFeeds, forKey: "selectedFeeds")
	}
	
}
