//
//  MainWindowState.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 12/16/23.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import Foundation

class MainWindowState: NSObject, NSSecureCoding {
	
	static var supportsSecureCoding = true
	
	let isFullScreen: Bool
	let splitViewWidths: [Int]
	let isSidebarHidden: Bool
	let sidebarWindowState: SidebarWindowState?
	let timelineWindowState: TimelineWindowState?
	let detailWindowState: DetailWindowState?

	init(isFullScreen: Bool, splitViewWidths: [Int], isSidebarHidden: Bool, sidebarWindowState: SidebarWindowState? = nil, timelineWindowState: TimelineWindowState? = nil, detailWindowState: DetailWindowState? = nil) {
		self.isFullScreen = isFullScreen
		self.splitViewWidths = splitViewWidths
		self.isSidebarHidden = isSidebarHidden
		self.sidebarWindowState = sidebarWindowState
		self.timelineWindowState = timelineWindowState
		self.detailWindowState = detailWindowState
	}

	required init?(coder: NSCoder) {
		isFullScreen = coder.decodeBool(forKey: "isFullScreen")
		splitViewWidths = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "splitViewWidths") as? [Int] ?? []
		isSidebarHidden = coder.decodeBool(forKey: "isSidebarHidden")
		sidebarWindowState = coder.decodeObject(of: SidebarWindowState.self, forKey: "sidebarWindowState")
		timelineWindowState = coder.decodeObject(of: TimelineWindowState.self, forKey: "timelineWindowState")
		detailWindowState = coder.decodeObject(of: DetailWindowState.self, forKey: "detailWindowState")
	}


	func encode(with coder: NSCoder) {
		coder.encode(isFullScreen, forKey: "isFullScreen")
		coder.encode(splitViewWidths, forKey: "splitViewWidths")
		coder.encode(isSidebarHidden, forKey: "isSidebarHidden")
		coder.encode(sidebarWindowState, forKey: "sidebarWindowState")
		coder.encode(timelineWindowState, forKey: "timelineWindowState")
		coder.encode(detailWindowState, forKey: "detailWindowState")
	}
	
}
