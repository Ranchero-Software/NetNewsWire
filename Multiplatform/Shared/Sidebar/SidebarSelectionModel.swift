//
//  SidebarSelectionModel.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 8/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account


class SidebarSelectionModel: ObservableObject {
	
	#if os(macOS)
	@Published var selectedSidebarItems = Set<FeedIdentifier>() {
		didSet {
			print(selectedSidebarItems)
		}
	}
	#endif
	
	private var items = Set<FeedIdentifier>() 
	
	@Published var selectedSidebarItem: FeedIdentifier? = .none {
		willSet {
			if newValue != nil {
				items.insert(newValue!)
			} else {
				selectedSidebarItems = items
				items.removeAll()
			}
		}
	}
}
