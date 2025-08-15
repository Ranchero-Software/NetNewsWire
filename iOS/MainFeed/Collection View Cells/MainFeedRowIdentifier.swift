//
//  MainFeedRowIdentifier.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/20/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation

class MainFeedRowIdentifier: NSObject, NSCopying {

	var indexPath: IndexPath
	
	init(indexPath: IndexPath) {
		self.indexPath = indexPath
	}
	
	func copy(with zone: NSZone? = nil) -> Any {
		return self
	}
	
}
