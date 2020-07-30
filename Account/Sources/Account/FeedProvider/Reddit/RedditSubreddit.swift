//
//  RedditSubreddit.swift
//  Account
//
//  Created by Maurice Parker on 5/4/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct RedditSubreddit: Codable {

    let kind: String?
	let data: RedditSubredditData?
    
    enum CodingKeys: String, CodingKey {
        case kind = "kind"
        case data = "data"
    }
	
}

struct RedditSubredditData: Codable {
	
	let displayName: String?
	let iconImg: String?
	let communityIcon: String?

	enum CodingKeys: String, CodingKey {
		case displayName = "display_name_prefixed"
		case iconImg = "icon_img"
		case communityIcon = "community_icon"
	}
	
	var iconURL: String? {
		if let communityIcon = communityIcon, !communityIcon.isEmpty {
			return communityIcon
		} else {
			return iconImg
		}
	}
	
}
