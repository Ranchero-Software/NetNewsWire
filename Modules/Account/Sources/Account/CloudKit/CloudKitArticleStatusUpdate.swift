//
//  CloudKitArticleStatusUpdate.swift
//  Account
//
//  Created by Maurice Parker on 4/29/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import SyncDatabase
import Articles

struct CloudKitArticleStatusUpdate {
	
	enum Record {
		case all
		case new
		case statusOnly
		case delete
	}
	
	var articleID: String
	var statuses: [SyncStatus]
	var article: Article?
	
	init?(articleID: String, statuses: [SyncStatus], article: Article?) {
		self.articleID = articleID
		self.statuses = statuses
		self.article = article

		let rec = record
		// This is an invalid status update.  The article is required for new and all
		if article == nil && (rec == .all || rec == .new) {
			return nil
		}
	}
	
	var record: Record {
		if statuses.contains(where: { $0.key == .deleted }) {
			return .delete
		}
		
		if statuses.count == 1, statuses.first!.key == .new {
			return .new
		}
		
		if let article = article {
			if article.status.read == false || article.status.starred == true {
				return .all
			}
		}

		return .statusOnly
	}
	
	var isRead: Bool {
		if let article = article {
			return article.status.read
		}
		return true
	}
	
	var isStarred: Bool {
		if let article = article {
			return article.status.starred
		}
		return false
	}
	
}
