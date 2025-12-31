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

@MainActor func markArticles(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: (() -> Void)? = nil) {
	let d: [String: Set<Article>] = accountAndArticlesDictionary(articles)

	let group = DispatchGroup()

	for (accountID, accountArticles) in d {
		guard let account = AccountManager.shared.existingAccount(accountID: accountID) else {
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

@MainActor extension Article {
	var feed: Feed? {
		return account?.existingFeed(withFeedID: feedID)
	}

	var url: URL? {
		return URL.encodeSpacesIfNeeded(rawLink)
	}

	var externalURL: URL? {
		return URL.encodeSpacesIfNeeded(rawExternalLink)
	}

	var imageURL: URL? {
		return URL.encodeSpacesIfNeeded(rawImageLink)
	}

	var link: String? {
		// Prefer link from URL, if one can be created, as these are repaired if required.
		// Provide the raw link if URL creation fails.
		return url?.absoluteString ?? rawLink
	}

	var externalLink: String? {
		// Prefer link from externalURL, if one can be created, as these are repaired if required.
		// Provide the raw link if URL creation fails.
		return externalURL?.absoluteString ?? rawExternalLink
	}

	var imageLink: String? {
		// Prefer link from imageURL, if one can be created, as these are repaired if required.
		// Provide the raw link if URL creation fails.
		return imageURL?.absoluteString ?? rawImageLink
	}

	var preferredLink: String? {
		if let link = link, !link.isEmpty {
			return link
		}
		if let externalLink = externalLink, !externalLink.isEmpty {
			return externalLink
		}
		return nil
	}

	var preferredURL: URL? {
		return url ?? externalURL
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

	func iconImageUrl(feed: Feed) -> URL? {
		if let image = iconImage() {
			let fm = FileManager.default
			var path = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
			let feedID = feed.feedID.replacingOccurrences(of: "/", with: "_")
			path.appendPathComponent(feedID + "_smallIcon.png")
			fm.createFile(atPath: path.path, contents: image.image.dataRepresentation()!, attributes: nil)
			return path
		} else {
			return nil
		}
	}

	func byline() -> String {
		guard let authors = authors ?? feed?.authors, !authors.isEmpty else {
			return ""
		}

		// If the author's name is the same as the feed, then we don't want to display it.
		// This code assumes that multiple authors would never match the feed name so that
		// if there feed owner has an article co-author all authors are given the byline.
		if authors.count == 1, let author = authors.first {
			if author.name == feed?.nameForDisplay {
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
	static let feedID = "feedID"
	static let articleID = "articleID"
}

@MainActor extension Article {

	public var pathUserInfo: [AnyHashable: Any] {
		return [
			ArticlePathKey.accountID: accountID,
			ArticlePathKey.accountName: account?.nameForDisplay ?? "",
			ArticlePathKey.feedID: feedID,
			ArticlePathKey.articleID: articleID
		]
	}
}

// MARK: SortableArticle

@MainActor extension Article: SortableArticle {
	var sortableName: String {
		return feed?.name ?? ""
	}

	var sortableDate: Date {
		return logicalDatePublished
	}

	var sortableArticleID: String {
		return articleID
	}

	var sortableFeedID: String {
		return feedID
	}
}
