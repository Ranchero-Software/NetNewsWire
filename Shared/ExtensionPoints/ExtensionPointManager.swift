//
//  ExtensionPointManager.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import FeedProvider
import RSCore

final class ExtensionPointManager {
	
	static let shared = ExtensionPointManager()

	var activeExtensionPoints = [ExtensionPointIdentifer: ExtensionPoint]()
	let availableExtensionPointTypes: [ExtensionPointType]
	
	var activeSendToCommands: [SendToCommand] {
		return activeExtensionPoints.values.compactMap({ return $0 as? SendToCommand })
	}
	
	var activeFeedProviders: [FeedProvider] {
		return activeExtensionPoints.values.compactMap({ return $0 as? FeedProvider })
	}
	
	init() {
		#if os(macOS)
		#if DEBUG
		availableExtensionPointTypes = [.marsEdit, .microblog, .twitter]
		#else
		availableExtensionPointTypes = [.marsEdit, .microblog, .twitter]
		#endif
		#else
		#if DEBUG
		availableExtensionPoints = [.twitter]
		#else
		availableExtensionPoints = [.twitter]
		#endif
		#endif
		loadExtensionPointIDs()
	}
	
	func activateExtensionPoint(_ extensionPointID: ExtensionPointIdentifer) {
		activeExtensionPoints[extensionPointID] = extensionPoint(for: extensionPointID)
		saveExtensionPointIDs()
	}
	
	func deactivateExtensionPoint(_ extensionPointID: ExtensionPointIdentifer) {
		activeExtensionPoints[extensionPointID] = nil
		saveExtensionPointIDs()
	}
	
}

private extension ExtensionPointManager {
	
	func loadExtensionPointIDs() {
		if let extensionPointUserInfos = AppDefaults.activeExtensionPointIDs {
			for extensionPointUserInfo in extensionPointUserInfos {
				if let extensionPointID = ExtensionPointIdentifer(userInfo: extensionPointUserInfo) {
					activeExtensionPoints[extensionPointID] = extensionPoint(for: extensionPointID)
				}
			}
		}
	}
	
	func saveExtensionPointIDs() {
		AppDefaults.activeExtensionPointIDs = activeExtensionPoints.keys.map({ $0.userInfo })
	}
	
	func extensionPoint(for extensionPointID: ExtensionPointIdentifer) -> ExtensionPoint {
		switch extensionPointID {
		case .marsEdit:
			return SendToMarsEditCommand()
		case .microblog:
			return SendToMicroBlogCommand()
		case .twitter(let username):
			return TwitterFeedProvider(username: username)
		}
	}
	
}
