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
}
