//
//  ArticleSpecifier.swift
//  Articles
//
//  Created by Brent Simmons on 12/1/25.
//

import Foundation
import Articles

/// Use this to refer to an Article when you can look it up.
///
/// For instance, this can be saved to disk as part of state restoration.
struct ArticleSpecifier: Hashable, Sendable {
	let accountID: String
	let articleID: String

	private struct Key {
		static let accountID = "accountID"
		static let articleID = "articleID"
	}

	/// Plist-compatible dictionary, meant to be saved to disk or in UserDefaults.
	var dictionary: [String: String] {
		[Key.accountID: accountID, Key.articleID: articleID]
	}

	init(accountID: String, articleID: String) {
		self.accountID = accountID
		self.articleID = articleID
	}

	init?(dictionary: [String: String]) {
		guard let accountID = dictionary[Key.accountID],
			  let articleID = dictionary[Key.articleID] else {
			return nil
		}
		self.init(accountID: accountID, articleID: articleID)
	}

	init(article: Article) {
		self.init(accountID: article.accountID, articleID: article.articleID)
	}

	func matchesArticle(_ article: Article) -> Bool {
		article.accountID == accountID && article.articleID == articleID
	}
}
