//
//  SceneModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

final class SceneModel: ObservableObject {
	
	var sidebarModel: SidebarModel?
	
}

// MARK: SidebarModelDelegate

extension SceneModel: SidebarModelDelegate {
	
	func sidebarSelectionDidChange(_: SidebarModel, feeds: [Feed]?) {
		print("**** sidebar selection changed ***")
	}
	
}
