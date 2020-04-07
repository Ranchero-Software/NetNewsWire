//
//  ExtensionPointType.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

enum ExtensionPoint: Int, Codable {
	case sentToCommand = 1
	case feedProvider = 2
}
