//
//  ArticleUtilities.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/25/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Articles
import Account

// These handle multiple accounts.

func markArticles(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: (() -> Void)? = nil) {
	
	let d: [String: Set<Article>] = accountAndArticlesDictionary(articles)

	let group = DispatchGroup()
	
	for (accountID, accountArticles) in d {
		guard let account = AccountManager.shared.existingAccount(with: accountID) else {
			continue
		}
		group.enter()
		account.markArticles(accountArticles, statusKey: statusKey, flag: flag) { _ in
			group.leave()
		}
	}
	
	group.notify(queue: .main) {
		completion?()
	}
}

private func accountAndArticlesDictionary(_ articles: Set<Article>) -> [String: Set<Article>] {
	
	let d = Dictionary(grouping: articles, by: { $0.accountID })
	return d.mapValues{ Set($0) }
}

extension Article {
	
	var webFeed: WebFeed? {
		return account?.existingWebFeed(withWebFeedID: webFeedID)
	}
	
	var preferredLink: String? {
		if let url = url, !url.isEmpty {
			return url
		}
		if let externalURL = externalURL, !externalURL.isEmpty {
			return externalURL
		}
		return nil
	}
	
	var preferredURL: URL? {
		guard let link = preferredLink else { return nil }
		// If required, we replace any space characters to handle malformed links that are otherwise percent
		// encoded but contain spaces. For performance reasons, only try this if initial URL init fails.
		if let url = URL(string: link) {
			return url
		} else if let url = URL(string: link.replacingOccurrences(of: " ", with: "%20")) {
			return url
		}
		return nil
	}
	
	var body: String? {
		return contentHTML ?? contentText ?? summary
	}
	
	var logicalDatePublished: Date {
		return datePublished ?? dateModified ?? status.dateArrived
	}
	
	var isAvailableToMarkUnread: Bool {
		guard let markUnreadWindow = account?.behaviors.compactMap( { behavior -> Int? in
			switch behavior {
			case .disallowMarkAsUnreadAfterPeriod(let days):
				return days
			default:
				return nil
			}
		}).first else {
			return true
		}
		
		if logicalDatePublished.byAdding(days: markUnreadWindow) > Date() {
			return true
		} else {
			return false
		}
	}

	func iconImage() -> IconImage? {
		return IconImageCache.shared.imageForArticle(self)
	}
	
	func iconImageUrl(webFeed: WebFeed) -> URL? {
		if let image = iconImage() {
			let fm = FileManager.default
			var path = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			let feedID = webFeed.webFeedID.replacingOccurrences(of: "/", with: "_")
			#if os(macOS)
			path.appendPathComponent(feedID + "_smallIcon.tiff")
			#else
			path.appendPathComponent(feedID + "_smallIcon.png")
			#endif
			fm.createFile(atPath: path.path, contents: image.image.dataRepresentation()!, attributes: nil)
			return path
		} else {
			return nil
		}
	}
	
	func byline() -> String {
		guard let authors = authors ?? webFeed?.authors, !authors.isEmpty else {
			return ""
		}

		// If the author's name is the same as the feed, then we don't want to display it.
		// This code assumes that multiple authors would never match the feed name so that
		// if there feed owner has an article co-author all authors are given the byline.
		if authors.count == 1, let author = authors.first {
			if author.name == webFeed?.nameForDisplay {
				return ""
			}
		}
		
		var byline = ""
		var isFirstAuthor = true

		for author in authors {
			if !isFirstAuthor {
				byline += ", "
			}
			isFirstAuthor = false
			
			var authorEmailAddress: String? = nil
			if let emailAddress = author.emailAddress, !(emailAddress.contains("noreply@") || emailAddress.contains("no-reply@")) {
				authorEmailAddress = emailAddress
			}

			if let emailAddress = authorEmailAddress, emailAddress.contains(" ") {
				byline += emailAddress // probably name plus email address
			}
			else if let name = author.name, let emailAddress = authorEmailAddress {
				byline += "\(name) <\(emailAddress)>"
			}
			else if let name = author.name {
				byline += name
			}
			else if let emailAddress = authorEmailAddress {
				byline += "<\(emailAddress)>"
			}
			else if let url = author.url {
				byline += url
			}
		}

		return byline
	}
	
}

// MARK: Path

struct ArticlePathKey {
	static let accountID = "accountID"
	static let accountName = "accountName"
	static let webFeedID = "webFeedID"
	static let articleID = "articleID"
}

extension Article {

	public var pathUserInfo: [AnyHashable : Any] {
		return [
			ArticlePathKey.accountID: accountID,
			ArticlePathKey.accountName: account?.nameForDisplay ?? "",
			ArticlePathKey.webFeedID: webFeedID,
			ArticlePathKey.articleID: articleID
		]
	}

}

// MARK: SortableArticle

extension Article: SortableArticle {
	
	var sortableName: String {
		return webFeed?.name ?? ""
	}
	
	var sortableDate: Date {
		return logicalDatePublished
	}
	
	var sortableArticleID: String {
		return articleID
	}
	
	var sortableWebFeedID: String {
		return webFeedID
	}
	
}
