//
//  Article+Database.swift
//  Database
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Data

extension Article {
	
	convenience init?(row: FMResultSet, account: Account) {
		
		guard let feedID = row.string(forColumn: DatabaseKey.feedID) else {
			return nil
		}
		guard let uniqueID = row.string(forColumn: DatabaseKey.uniqueID) else {
			return nil
		}
		
		let articleID = row.string(forColumn: DatabaseKey.articleID)!
		let title = row.string(forColumn: DatabaseKey.title)
		let contentHTML = row.string(forColumn: DatabaseKey.contentHTML)
		let contentText = row.string(forColumn: DatabaseKey.contentText)
		let url = row.string(forColumn: DatabaseKey.url)
		let externalURL = row.string(forColumn: DatabaseKey.externalURL)
		let summary = row.string(forColumn: DatabaseKey.summary)
		let imageURL = row.string(forColumn: DatabaseKey.imageURL)
		let bannerImageURL = row.string(forColumn: DatabaseKey.bannerImageURL)
		let datePublished = row.date(forColumn: DatabaseKey.datePublished)
		let dateModified = row.date(forColumn: DatabaseKey.dateModified)
		let authors = PropertyListTransformer.authorsWithRow(row)
		let tags = PropertyListTransformer.tagsWithRow(row)
		let attachments = PropertyListTransformer.attachmentsWithRow(row)
		let accountInfo = accountInfoWithRow(row)
		
		self.init(account: account, feedID: feed, uniqueID: uniqueID, title: title, contentHTML: contentHTML, contentText: contentText, url: url, externalURL: externalURL, summary: summary, imageURL: imageURL, bannerImageURL: bannerImageURL, datePublished: datePublished, dateModified: dateModified, authors: authors, tags: tags, attachments: attachments, accountInfo: accountInfo)
	}

	func databaseDictionary() -> NSDictionary {
		
		var d = NSMutableDictionary()
		
		
		return d.copy() as! NSDictionary
	}
}
