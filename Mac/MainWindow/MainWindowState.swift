//
//  MainWindowState.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 12/16/23.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import Foundation

final class MainWindowState: NSObject, NSSecureCoding {

	static let supportsSecureCoding = true

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

	private struct Key {
		static let isFullScreen = "isFullScreen"
		static let splitViewWidths = "splitViewWidths"
		static let isSidebarHidden = "isSidebarHidden"
		static let sidebarWindowState = "sidebarWindowState"
		static let timelineWindowState = "timelineWindowState"
		static let detailWindowState = "detailWindowState"
	}

	required init?(coder: NSCoder) {
		isFullScreen = coder.decodeBool(forKey: Key.isFullScreen)
		splitViewWidths = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: Key.splitViewWidths) as? [Int] ?? []
		isSidebarHidden = coder.decodeBool(forKey: Key.isSidebarHidden)
		sidebarWindowState = coder.decodeObject(of: SidebarWindowState.self, forKey: Key.sidebarWindowState)
		timelineWindowState = coder.decodeObject(of: TimelineWindowState.self, forKey: Key.timelineWindowState)
		detailWindowState = coder.decodeObject(of: DetailWindowState.self, forKey: Key.detailWindowState)
	}

	func encode(with coder: NSCoder) {
		coder.encode(isFullScreen, forKey: Key.isFullScreen)
		coder.encode(splitViewWidths, forKey: Key.splitViewWidths)
		coder.encode(isSidebarHidden, forKey: Key.isSidebarHidden)
		coder.encode(sidebarWindowState, forKey: Key.sidebarWindowState)
		coder.encode(timelineWindowState, forKey: Key.timelineWindowState)
		coder.encode(detailWindowState, forKey: Key.detailWindowState)
	}

	override var description: String {
		let sidebar = sidebarWindowState?.description ?? "nil"
		let timeline = timelineWindowState?.description ?? "nil"
		let detail = detailWindowState?.description ?? "nil"
		return "MainWindowState: fullScreen=\(isFullScreen), widths=\(splitViewWidths), sidebarHidden=\(isSidebarHidden), sidebar=[\(sidebar)], timeline=[\(timeline)], detail=[\(detail)]"
	}
}
