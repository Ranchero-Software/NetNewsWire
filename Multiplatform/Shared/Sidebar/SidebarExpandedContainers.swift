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

final class SidebarExpandedContainers: ObservableObject {
	
	@Published var expandedTable = Set<ContainerIdentifier>()
	var objectDidChange = PassthroughSubject<Void, Never>()
	
	var data: Data {
		get {
			let encoder = PropertyListEncoder()
			encoder.outputFormat = .binary
			return (try? encoder.encode(expandedTable)) ?? Data()
		}
		set {
			let decoder = PropertyListDecoder()
			expandedTable = (try? decoder.decode(Set<ContainerIdentifier>.self, from: newValue)) ?? Set<ContainerIdentifier>()
		}
	}
	
	subscript(_ containerID: ContainerIdentifier) -> Bool {
		get {
			return expandedTable.contains(containerID)
		}
		set(newValue) {
			if newValue {
				expandedTable.insert(containerID)
			} else {
				expandedTable.remove(containerID)
			}
			objectDidChange.send()
		}
	}
	
}
