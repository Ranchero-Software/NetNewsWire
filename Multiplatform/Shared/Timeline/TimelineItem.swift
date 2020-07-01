//
//  TimelineItem.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/30/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Articles

enum TimelineItemStatus {
	case showStar
	case showUnread
	case showNone
}

struct TimelineItem: Identifiable {
	
	var article: Article
	
	var id: String {
		return article.articleID
	}
	
	var status:  TimelineItemStatus {
		if article.status.starred == true {
			return .showStar
		}
		if article.status.read == false {
			return .showUnread
		}
		return .showNone
	}
	
}
