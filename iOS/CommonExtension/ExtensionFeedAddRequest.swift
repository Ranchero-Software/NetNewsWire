//
//  ExtensionFeedAddRequest.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

struct ExtensionFeedAddRequest: Codable {
	
	enum CodingKeys: String, CodingKey {
		case name
		case feedURL
		case destinationContainerID
	}

	let name: String?
	let feedURL: URL
	let destinationContainerID: ContainerIdentifier
	
}
