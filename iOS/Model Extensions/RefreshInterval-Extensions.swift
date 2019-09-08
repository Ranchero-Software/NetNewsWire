//
//  RefreshInterval-Extensions.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/7/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

extension RefreshInterval: Identifiable {
	var id: Int {
		return rawValue
	}
}
