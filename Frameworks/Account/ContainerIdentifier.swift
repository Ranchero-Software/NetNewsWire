//
//  ContainerIdentifier.swift
//  Account
//
//  Created by Maurice Parker on 11/24/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol ContainerIdentifiable {
	var containerID: ContainerIdentifier? { get }
}

public enum ContainerIdentifier: Hashable {
	case smartFeedController
	case account(String) // accountID
	case folder(String, String) // accountID, folderName
	
	public var userInfo: [AnyHashable: AnyHashable] {
		switch self {
		case .smartFeedController:
			return [
				"type": "smartFeedController"
			]
		case .account(let accountID):
			return [
				"type": "account",
				"accountID": accountID
			]
		case .folder(let accountID, let folderName):
			return [
				"type": "folder",
				"accountID": accountID,
				"folderName": folderName
			]
		}
	}
	
	public init?(userInfo: [AnyHashable: AnyHashable]) {
		guard let type = userInfo["type"] as? String else { return nil }
		
		switch type {
		case "smartFeedController":
			self = ContainerIdentifier.smartFeedController
		case "account":
			guard let accountID = userInfo["accountID"] as? String else { return nil }
			self = ContainerIdentifier.account(accountID)
		case "folder":
			guard let accountID = userInfo["accountID"] as? String, let folderName = userInfo["folderName"] as? String else { return nil }
			self = ContainerIdentifier.folder(accountID, folderName)
		default:
			return nil
		}
	}
	
}
