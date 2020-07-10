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
	
	init(article: Article) {
		self.article = article
		updateStatus()
	}
	
	var id: String {
		return article.articleID
	}
	
	var status:  TimelineItemStatus = .showNone
	
	var byline: String {
		return article.webFeed?.nameForDisplay ?? ""
	}
	
	var dateTimeString: String {
		return ArticleStringFormatter.dateString(article.logicalDatePublished)
	}
	
	mutating func updateStatus() {
		if article.status.starred == true {
			status = .showStar
		} else {
			if article.status.read == false {
				status = .showUnread
			} else {
				status = .showNone
			}
		}
	}
	
}
