//
//  SidebarExpandedContainers.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/30/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Combine
import Account

struct SidebarExpandedContainers {
	
	var expandedTable = [ContainerIdentifier: Bool]()
	
	var data: Data {
		get {
			let encoder = PropertyListEncoder()
			encoder.outputFormat = .binary
			return (try? encoder.encode(expandedTable)) ?? Data()
		}
		set {
			let decoder = PropertyListDecoder()
			expandedTable = (try? decoder.decode([ContainerIdentifier: Bool].self, from: newValue)) ?? [ContainerIdentifier: Bool]()
		}
	}
	
	func contains(_ containerID: ContainerIdentifier) -> Bool {
		return expandedTable.keys.contains(containerID)
	}
	
	subscript(_ containerID: ContainerIdentifier) -> Bool {
		get {
			if let result = expandedTable[containerID] {
				return result
			}
			switch containerID {
			case .smartFeedController, .account:
				return true
			default:
				return false
			}
		}
		set(newValue) {
			expandedTable[containerID] = newValue
		}
	}
	
}
