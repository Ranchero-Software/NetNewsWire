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

public extension Notification.Name {
	static let ActiveExtensionPointsDidChange = Notification.Name(rawValue: "ActiveExtensionPointsDidChange")
}

final class ExtensionPointManager {
	
	static let shared = ExtensionPointManager()

	var activeExtensionPoints = [ExtensionPointIdentifer: ExtensionPoint]()
	let possibleExtensionPointTypes: [ExtensionPointType]
	var availableExtensionPointTypes: [ExtensionPointType] {
		
		let activeExtensionPointTypes = Set(activeExtensionPoints.keys.compactMap({ $0.type }))
		var available = [ExtensionPointType]()
		for possibleExtensionPointType in possibleExtensionPointTypes {
			if possibleExtensionPointType.isSinglton {
				if !activeExtensionPointTypes.contains(possibleExtensionPointType) {
					available.append(possibleExtensionPointType)
				}
			} else {
				available.append(possibleExtensionPointType)
			}
		}
		
		return available
	}
	
	var activeSendToCommands: [SendToCommand] {
		return activeExtensionPoints.values.compactMap({ return $0 as? SendToCommand })
	}
	
	var activeFeedProviders: [FeedProvider] {
		return activeExtensionPoints.values.compactMap({ return $0 as? FeedProvider })
	}
	
	init() {
		#if os(macOS)
		#if DEBUG
		possibleExtensionPointTypes = [.marsEdit, .microblog, .twitter]
		#else
		possibleExtensionPointTypes = [.marsEdit, .microblog, .twitter]
		#endif
		#else
		#if DEBUG
		possibleExtensionPointTypes = [.twitter]
		#else
		possibleExtensionPointTypes = [.twitter]
		#endif
		#endif
		loadExtensionPoints()
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
	
	func loadExtensionPoints() {
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
		NotificationCenter.default.post(name: .ActiveExtensionPointsDidChange, object: nil, userInfo: nil)
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
