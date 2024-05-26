//
//  ContainerIdentifier.swift
//  Account
//
//  Created by Maurice Parker on 11/24/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol ContainerIdentifiable {
	
	@MainActor var containerID: ContainerIdentifier? { get }
}

public enum ContainerIdentifier: Hashable, Equatable, Sendable {
	
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
	
	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {

		switch self {
		case .smartFeedController:
			hasher.combine(0)
		case .account(let accountID):
			hasher.combine(accountID)
		case .folder(let accountID, let folderName):
			hasher.combine(accountID)
			hasher.combine(folderName)
		}
	}
}

extension ContainerIdentifier: Encodable {
    enum CodingKeys: CodingKey {
        case type
        case accountID
        case folderName
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .smartFeedController:
			try container.encode("smartFeedController", forKey: .type)
		case .account(let accountID):
			try container.encode("account", forKey: .type)
			try container.encode(accountID, forKey: .accountID)
		case .folder(let accountID, let folderName):
			try container.encode("folder", forKey: .type)
			try container.encode(accountID, forKey: .accountID)
			try container.encode(folderName, forKey: .folderName)
        }
    }
}

extension ContainerIdentifier: Decodable {
	
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
		let type =  try container.decode(String.self, forKey: .type)
		
		switch type {
		case "smartFeedController":
			self = .smartFeedController
		case "account":
			let accountID =  try container.decode(String.self, forKey: .accountID)
			self = .account(accountID)
		default:
			let accountID =  try container.decode(String.self, forKey: .accountID)
			let folderName =  try container.decode(String.self, forKey: .folderName)
			self = .folder(accountID, folderName)
		}
    }
	
}
