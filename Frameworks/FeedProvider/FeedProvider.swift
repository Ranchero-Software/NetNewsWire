//
//  FeedProvider.swift
//  FeedProvider
//
//  Created by Maurice Parker on 4/6/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

public enum FeedProviderType: Int, Codable {
	// Raw values should not change since they’re stored.
	case marsEdit = 1
	case microblog = 2
	case twitter = 3
}


protocol FeedProvider  {
	
}
