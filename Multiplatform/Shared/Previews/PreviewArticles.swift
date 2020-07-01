//
//  PreviewArticles.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/1/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Articles

enum PreviewArticles {
	
	static var basicUnread: Article {
		return makeBasicArticle(read: false, starred: false)
	}
	
	static var basicRead: Article {
		return makeBasicArticle(read: true, starred: false)
	}
	
	static var basicStarred: Article {
		return makeBasicArticle(read: false, starred: true)
	}
	
}

private extension PreviewArticles {
	
	static var shortTitle: String {
		return "Short article title"
	}
	
	static var shortSummary: String {
		return "Summary of article to be shown after title."
	}
	
	static func makeBasicArticle(read: Bool, starred: Bool) -> Article {
		let articleID = "prototype"
		let status = ArticleStatus(articleID: articleID, read: read, starred: starred, dateArrived: Date())
		return Article(accountID: articleID,
					   articleID: articleID,
					   webFeedID: articleID,
					   uniqueID: articleID,
					   title: shortTitle,
					   contentHTML: nil,
					   contentText: nil,
					   url: nil,
					   externalURL: nil,
					   summary: shortSummary,
					   imageURL: nil,
					   datePublished: Date(),
					   dateModified: nil,
					   authors: nil,
					   status: status)
	}
	
}
