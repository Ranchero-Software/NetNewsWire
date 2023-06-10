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

public enum ExtensionPointManagerError: LocalizedError {
	case unableToCreate
	
	public var localizedDescription: String {
		switch self {
		case .unableToCreate:
			return NSLocalizedString("Unable to create extension.", comment: "Unable to create extension")
		}
	}
}


final class ExtensionPointManager: FeedProviderManagerDelegate {
	
	static let shared = ExtensionPointManager()

	var activeExtensionPoints = [ExtensionPointIdentifer: ExtensionPoint]()
	let possibleExtensionPointTypes: [ExtensionPoint.Type]
	var availableExtensionPointTypes: [ExtensionPoint.Type] {
		
		let activeExtensionPointTypes = activeExtensionPoints.keys.compactMap({ ObjectIdentifier($0.extensionPointType) })
		var available = [ExtensionPoint.Type]()
		for possibleExtensionPointType in possibleExtensionPointTypes {
			if !(AppDefaults.shared.isDeveloperBuild && possibleExtensionPointType.isDeveloperBuildRestricted) {
				if possibleExtensionPointType.isSinglton {
					if !activeExtensionPointTypes.contains(ObjectIdentifier(possibleExtensionPointType)) {
						available.append(possibleExtensionPointType)
					}
				} else {
					available.append(possibleExtensionPointType)
				}
			}
		}
		
		return available
		
	}
	
	var activeSendToCommands: [SendToCommand] {
		var commands = activeExtensionPoints.values.compactMap({ return $0 as? SendToCommand })
		
		// These two SendToCommands don't need logins and are always active
		#if os(macOS)
		commands.append(SendToMarsEditCommand())
		commands.append(SendToMicroBlogCommand())
		#endif
		
		return commands
	}
	
	var activeFeedProviders: [FeedProvider] {
		return activeExtensionPoints.values.compactMap({ return $0 as? FeedProvider })
	}
	
	

	init() {
		possibleExtensionPointTypes = []
		loadExtensionPoints()
	}
	
	func activateExtensionPoint(_ extensionPointType: ExtensionPoint.Type, tokenSuccess: OAuthSwift.TokenSuccess? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
		self.extensionPoint(for: extensionPointType, tokenSuccess: tokenSuccess) { result in
			switch result {
			case .success(let extensionPoint):
				self.activeExtensionPoints[extensionPoint.extensionPointID] = extensionPoint
				self.saveExtensionPointIDs()
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func deactivateExtensionPoint(_ extensionPointID: ExtensionPointIdentifer) {
		activeExtensionPoints[extensionPointID] = nil
		saveExtensionPointIDs()
	}
	
}

private extension ExtensionPointManager {
	
	func loadExtensionPoints() {
		if let extensionPointUserInfos = AppDefaults.shared.activeExtensionPointIDs {
			for extensionPointUserInfo in extensionPointUserInfos {
				if let extensionPointID = ExtensionPointIdentifer(userInfo: extensionPointUserInfo) {
					activeExtensionPoints[extensionPointID] = extensionPoint(for: extensionPointID)
				}
			}
		}
	}
	
	func saveExtensionPointIDs() {
		AppDefaults.shared.activeExtensionPointIDs = activeExtensionPoints.keys.map({ $0.userInfo })
		NotificationCenter.default.post(name: .ActiveExtensionPointsDidChange, object: nil, userInfo: nil)
	}
	
	func extensionPoint(for extensionPointType: ExtensionPoint.Type, tokenSuccess: OAuthSwift.TokenSuccess?, completion: @escaping (Result<ExtensionPoint, Error>) -> Void) {
		return
	}
	
	func extensionPoint(for extensionPointID: ExtensionPointIdentifer) -> ExtensionPoint? {
		return nil
	}
	
	func feedProviderMatching(_ offered: URLComponents, ability: FeedProviderAbility) -> FeedProvider? {
		for extensionPoint in activeExtensionPoints.values {
			if let feedProvider = extensionPoint as? FeedProvider, feedProvider.ability(offered) == ability {
				return feedProvider
			}
		}
		return nil
	}

}
