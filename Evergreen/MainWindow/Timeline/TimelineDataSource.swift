//
//  TimelineDataSource.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

@objc final class TimelineDataSource: NSObject, NSTableViewDataSource {

	var articles = ArticleArray()
	
	func numberOfRows(in tableView: NSTableView) -> Int {

		return articles.count
	}

	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {

		return articles.articleAtRow(row) ?? nil
	}

	func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {

		guard let article = articles.articleAtRow(row) else {
			return nil
		}
		return ArticlePasteboardWriter(article: article)
	}
}
