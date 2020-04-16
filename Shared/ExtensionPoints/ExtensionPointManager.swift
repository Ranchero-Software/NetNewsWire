//
//  ExtensionPointManager.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import RSCore
import OAuthSwift

public extension Notification.Name {
	static let ActiveExtensionPointsDidChange = Notification.Name(rawValue: "ActiveExtensionPointsDidChange")
}

final class ExtensionPointManager: FeedProviderManagerDelegate {
	
	static let shared = ExtensionPointManager()

	var activeExtensionPoints = [ExtensionPointIdentifer: ExtensionPoint]()
	let possibleExtensionPointTypes: [ExtensionPoint.Type]
	var availableExtensionPointTypes: [ExtensionPoint.Type] {
		
		let activeExtensionPointTypes = activeExtensionPoints.keys.compactMap({ ObjectIdentifier($0.extensionPointType) })
		var available = [ExtensionPoint.Type]()
		for possibleExtensionPointType in possibleExtensionPointTypes {
			if possibleExtensionPointType.isSinglton {
				if !activeExtensionPointTypes.contains(ObjectIdentifier(possibleExtensionPointType)) {
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
		possibleExtensionPointTypes = [SendToMarsEditCommand.self, SendToMicroBlogCommand.self, TwitterFeedProvider.self]
		#else
		possibleExtensionPointTypes = [SendToMarsEditCommand.self, SendToMicroBlogCommand.self, TwitterFeedProvider.self]
		#endif
		#else
		#if DEBUG
		possibleExtensionPointTypes = [TwitterFeedProvider.self]
		#else
		possibleExtensionPointTypes = [TwitterFeedProvider.self]
		#endif
		#endif
		loadExtensionPoints()
	}
	
	func activateExtensionPoint(_ extensionPointType: ExtensionPoint.Type, tokenSuccess: OAuthSwift.TokenSuccess? = nil) {
		if let extensionPoint = self.extensionPoint(for: extensionPointType, tokenSuccess: tokenSuccess) {
			activeExtensionPoints[extensionPoint.extensionPointID] = extensionPoint
			saveExtensionPointIDs()
		}
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
	
	func extensionPoint(for extensionPointType: ExtensionPoint.Type, tokenSuccess: OAuthSwift.TokenSuccess?) -> ExtensionPoint? {
		switch extensionPointType {
		#if os(macOS)
		case is SendToMarsEditCommand.Type:
			return SendToMarsEditCommand()
		case is SendToMicroBlogCommand.Type:
			return SendToMicroBlogCommand()
		#endif
		case is TwitterFeedProvider.Type:
			if let tokenSuccess = tokenSuccess {
				return TwitterFeedProvider(tokenSuccess: tokenSuccess)
			} else {
				return nil
			}
		default:
			assertionFailure("Unrecognized Extension Point Type.")
		}
		return nil
	}
	
	func extensionPoint(for extensionPointID: ExtensionPointIdentifer) -> ExtensionPoint? {
		switch extensionPointID {
		#if os(macOS)
		case .marsEdit:
			return SendToMarsEditCommand()
		case .microblog:
			return SendToMicroBlogCommand()
		#endif
		case .twitter(let userID, let screenName):
			return TwitterFeedProvider(userID: userID, screenName: screenName)
		}
	}
	
	func feedProviderMatching(_ offered: URLComponents, forUsername username: String?, ability: FeedProviderAbility) -> FeedProvider? {
		for extensionPoint in activeExtensionPoints.values {
			if let feedProvider = extensionPoint as? FeedProvider, feedProvider.ability(offered, forUsername: username) == ability {
				return feedProvider
			}
		}
		return nil
	}

}
