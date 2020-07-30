//
//  RedditLinkListing.swift
//  Account
//
//  Created by Maurice Parker on 5/3/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct RedditLinkListing: Codable {
	
    let kind: String?
    let data: RedditLinkListingData?
	
	enum CodingKeys: String, CodingKey {
		case kind
		case data
	}
	
}

struct RedditLinkListingData: Codable {

	let children: [RedditLink]?

	enum CodingKeys: String, CodingKey {
		case children = "children"
	}

}
