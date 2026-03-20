//
//  AISummaryStore.swift
//  NetNewsWire
//
//  Created by Codex on 2026/3/20.
//

import Foundation
import Articles

final class AISummaryStore: @unchecked Sendable {
	static let shared = AISummaryStore()

	private var summaries = [String: String]()
	private var errors = [String: String]()
	private var loadingKeys = Set<String>()
	private let lock = NSLock()

	private init() {}

	func summary(for article: Article) -> String? {
		lock.lock()
		defer { lock.unlock() }
		return summaries[key(for: article)]
	}

	func isLoading(for article: Article) -> Bool {
		lock.lock()
		defer { lock.unlock() }
		return loadingKeys.contains(key(for: article))
	}

	func errorMessage(for article: Article) -> String? {
		lock.lock()
		defer { lock.unlock() }
		return errors[key(for: article)]
	}

	func setSummary(_ summary: String, for article: Article) {
		lock.lock()
		defer { lock.unlock() }
		let articleKey = key(for: article)
		summaries[articleKey] = summary
		errors.removeValue(forKey: articleKey)
	}

	func setErrorMessage(_ errorMessage: String, for article: Article) {
		lock.lock()
		defer { lock.unlock() }
		let articleKey = key(for: article)
		errors[articleKey] = errorMessage
	}

	func setLoading(_ isLoading: Bool, for article: Article) {
		lock.lock()
		defer { lock.unlock() }
		let articleKey = key(for: article)
		if isLoading {
			loadingKeys.insert(articleKey)
			errors.removeValue(forKey: articleKey)
		} else {
			loadingKeys.remove(articleKey)
		}
	}

	func clearSummary(for article: Article) {
		lock.lock()
		defer { lock.unlock() }
		let articleKey = key(for: article)
		summaries.removeValue(forKey: articleKey)
		errors.removeValue(forKey: articleKey)
		loadingKeys.remove(articleKey)
	}

	private func key(for article: Article) -> String {
		"\(article.accountID)|\(article.articleID)"
	}
}
