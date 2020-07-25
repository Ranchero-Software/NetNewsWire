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
	
	var id: String
	var position: Int
	var article: Article

	var status: TimelineItemStatus = .showNone
	var truncatedTitle: String
	var truncatedSummary: String
	var byline: String
	var dateTimeString: String
	
	init(position: Int, article: Article) {
		self.id = article.articleID
		self.position = position
		self.article = article
		self.byline = article.webFeed?.nameForDisplay ?? ""
		self.dateTimeString = ArticleStringFormatter.dateString(article.logicalDatePublished)
		self.truncatedTitle = ArticleStringFormatter.truncatedTitle(article)
		self.truncatedSummary = ArticleStringFormatter.truncatedSummary(article)
		updateStatus()
	}
	
	var isReadOnly: Bool {
		return article.status.read == true && article.status.starred == false
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
	
	func numberOfTitleLines(width: CGFloat) -> Int {
		guard !truncatedTitle.isEmpty else { return 0 }
		
		#if os(macOS)
		let descriptor = NSFont.preferredFont(forTextStyle: .body).fontDescriptor.withSymbolicTraits(.bold)
		guard let font = NSFont(descriptor: descriptor, size: 0) else { return 0 }
		#else
		guard let descriptor = UIFont.preferredFont(forTextStyle: .body).fontDescriptor.withSymbolicTraits(.traitBold) else { return 0 }
		let font = UIFont(descriptor: descriptor, size: 0)
		#endif
		
		let lines = Int(AppDefaults.shared.timelineNumberOfLines)
		let sizeInfo = TimelineTextSizer.size(for: truncatedTitle, font: font, numberOfLines: lines, width: adjustedWidth(width))
		return sizeInfo.numberOfLinesUsed
	}
	
	func numberOfSummaryLines(width: CGFloat, titleLines: Int) -> Int {
		guard !truncatedSummary.isEmpty else { return 0 }

		let remainingLines = Int(AppDefaults.shared.timelineNumberOfLines) - titleLines
		guard remainingLines > 0 else { return 0 }
		
		#if os(macOS)
		let font = NSFont.preferredFont(forTextStyle: .body)
		#else
		let font = UIFont.preferredFont(forTextStyle: .body)
		#endif
		
		let sizeInfo = TimelineTextSizer.size(for: truncatedSummary, font: font, numberOfLines: remainingLines, width: adjustedWidth(width))
		return sizeInfo.numberOfLinesUsed
	}
	
}

private extension TimelineItem {
	
	// This clearly isn't correct yet, but it gets us close enough for now.  -Maurice
	func adjustedWidth(_ width: CGFloat) -> Int {
		return Int(width - CGFloat(AppDefaults.shared.timelineIconDimensions + 64))
	}
	
}
