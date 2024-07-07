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

public struct CloudKitArticleStatusUpdate {
	
	public enum Record: Sendable {
		case all
		case new
		case statusOnly
		case delete
	}
	
	public var articleID: String
	public var statuses: [SyncStatus]
	public var article: Article?

	public init?(articleID: String, statuses: [SyncStatus], article: Article?) {
		self.articleID = articleID
		self.statuses = statuses
		self.article = article

		let rec = record
		// This is an invalid status update.  The article is required for new and all
		if article == nil && (rec == .all || rec == .new) {
			return nil
		}
	}
	
	public var record: Record {
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
	
	public var isRead: Bool {
		if let article = article {
			return article.status.read
		}
		return true
	}
	
	public var isStarred: Bool {
		if let article = article {
			return article.status.starred
		}
		return false
	}
}
