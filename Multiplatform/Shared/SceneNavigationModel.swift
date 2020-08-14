//
//  SceneNavigationModel.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 13/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation


class SceneNavigationModel: ObservableObject {
	@Published var sheetToShow: SidebarSheets = .none {
		didSet {
			sheetToShow != .none ? (showSheet = true) : (showSheet = false)
		}
	}
	@Published var showSheet = false
	@Published var showShareSheet = false
	@Published var showAccountSyncErrorAlert = false
}
