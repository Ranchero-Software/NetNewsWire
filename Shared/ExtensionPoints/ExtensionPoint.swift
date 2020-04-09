//
//  ExtensionPoint.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

protocol ExtensionPoint {

	var extensionPointType: ExtensionPointType { get }
	var extensionPointID: ExtensionPointIdentifer { get }
	
}

extension ExtensionPoint {
	
	var title: String {
		return extensionPointID.title
	}
	
}
