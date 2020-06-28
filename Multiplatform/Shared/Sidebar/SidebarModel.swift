//
//  SidebarModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

protocol SidebarModelDelegate: class {
	func sidebarSelectionDidChange(_: SidebarModel, feeds: [Feed]?)
}

class SidebarModel: ObservableObject {
	
	weak var delegate: SidebarModelDelegate?
	
}
