//
//  ArticleImagePrefetcher.swift
//  NetNewsWire
//
//  When offline image caching is enabled, downloads the images embedded in newly
//  arrived articles so they're available on disk before the article is ever opened.
//
//  Observes .AccountDidDownloadArticles (posted after each refresh) rather than
//  reaching into Account internals. Pairs with ArticleImageSchemeHandler, which
//  serves the cached bytes to the web view at render time.
//

import Foundation
import Account
import Articles
import Images
import RSWeb

extension Notification.Name {
	/// Posted (object: ArticleImagePrefetcher.shared) when a "cache all images" run
	/// starts, makes progress, or finishes, so settings UI can update its progress line.
	static let ArticleImageCacheAllProgressDidChange = Notification.Name("ArticleImageCacheAllProgressDidChange")
}

@MainActor final class ArticleImagePrefetcher {

	static let shared = ArticleImagePrefetcher()

	/// State of an in-progress "Cache All Images Now" run. `total` is the number of image
	/// URLs the run will attempt; `completed` counts those finished (including ones already
	/// cached, which complete immediately).
	private(set) var isCachingAll = false
	private(set) var cacheAllCompleted = 0
	private(set) var cacheAllTotal = 0

	private static let maxConcurrentCacheAll = 4

	/// Call once at app startup to begin observing.
	func start() {
		// The downloader lives in the Images module and can't read AppDefaults, so hand it a
		// check it can consult before draining its prefetch queue — turning the setting off
		// mid-refresh then stops queued downloads.
		ArticleImageDownloader.shared.isPrefetchingEnabled = { AppDefaults.shared.cacheImagesForOffline }
		// Apply the same tracker/ad block list to redirects: URLSession would otherwise follow a
		// 302 from an allowed URL to a blocked domain, since the block check only sees the initial
		// URL. (Applies to all Downloader traffic — favicons/feed icons too — which is a net win.)
		let contentBlocker = ArticleImageContentBlocker.shared
		Downloader.shared.redirectValidator = { url in
			!contentBlocker.isBlocked(url.absoluteString)
		}
		NotificationCenter.default.addObserver(self, selector: #selector(accountDidDownloadArticles(_:)), name: .AccountDidDownloadArticles, object: nil)
	}

	@objc func accountDidDownloadArticles(_ note: Notification) {
		guard AppDefaults.shared.cacheImagesForOffline else {
			return
		}
		guard let articles = note.userInfo?[Account.UserInfoKey.newArticles] as? Set<Article> else {
			return
		}
		prefetch(articles)
	}

	/// Force-fetch images for every unread article right now, bypassing the usual
	/// new-articles trigger. Invoked from the confirmation prompt shown when the user
	/// switches offline caching on. Reports progress via
	/// `.ArticleImageCacheAllProgressDidChange`; a no-op if a run is already in progress.
	func cacheAllArticleImagesNow() {
		guard !isCachingAll else {
			return
		}
		isCachingAll = true
		cacheAllCompleted = 0
		cacheAllTotal = 0
		postCacheAllProgress()
		Task { @MainActor in
			await runCacheAll()
		}
	}

	private func runCacheAll() async {
		let articles = await AccountManager.shared.fetchArticlesAsync(.unread(nil))
		let inputs: [ArticleImageURLExtractor.Input] = articles.compactMap { article in
			guard let html = article.body, !html.isEmpty else {
				return nil
			}
			return ArticleImageURLExtractor.Input(html: html, baseURLString: Self.baseURLString(for: article))
		}
		let extracted = await Task.detached(priority: .utility) {
			ArticleImageURLExtractor.imageURLStrings(in: inputs)
		}.value
		let urlStrings = extracted.filter { !ArticleImageContentBlocker.shared.isBlocked($0) }

		cacheAllTotal = urlStrings.count
		postCacheAllProgress()

		guard !urlStrings.isEmpty else {
			finishCacheAll()
			return
		}

		// Download in batches so at most maxConcurrentCacheAll are in flight at once, rather than
		// enqueueing an unbounded burst. data(for:allowNetwork:) caches to disk as a side effect.
		var start = 0
		while start < urlStrings.count {
			// Stop launching new batches if the user turned offline caching off mid-run, so we
			// don't keep hitting the network and writing to disk after they've opted out. (An
			// already-launched batch finishes, matching the refresh-prefetch gate's behavior.)
			guard AppDefaults.shared.cacheImagesForOffline else {
				break
			}
			let end = min(start + Self.maxConcurrentCacheAll, urlStrings.count)
			var tasks = [Task<Void, Never>]()
			for index in start..<end {
				let url = urlStrings[index]
				tasks.append(Task { @MainActor in
					_ = await ArticleImageDownloader.shared.data(for: url, allowNetwork: true)
				})
			}
			for task in tasks {
				await task.value
				cacheAllCompleted += 1
				postCacheAllProgress()
			}
			start = end
		}

		finishCacheAll()
	}

	private func finishCacheAll() {
		isCachingAll = false
		ArticleImageDownloader.shared.enforceDiskCacheLimit() // a big run may have pushed past the cap
		postCacheAllProgress()
	}

	private func postCacheAllProgress() {
		NotificationCenter.default.post(name: .ArticleImageCacheAllProgressDidChange, object: self)
	}

	func prefetch(_ articles: Set<Article>) {
		// Snapshot the strings we need while on the main thread (cheap property reads),
		// then parse the HTML off the main thread: a syncing account can deliver a large
		// batch of new articles in one notification, and running the regexes on the main
		// thread would hitch the UI. Enqueue the downloads back on the main thread, since
		// ArticleImageDownloader is main-actor isolated.
		let inputs: [ArticleImageURLExtractor.Input] = articles.compactMap { article in
			guard let html = article.body, !html.isEmpty else {
				return nil
			}
			return ArticleImageURLExtractor.Input(html: html, baseURLString: Self.baseURLString(for: article))
		}
		guard !inputs.isEmpty else {
			return
		}

		Task.detached(priority: .utility) {
			let urlStrings = ArticleImageURLExtractor.imageURLStrings(in: inputs)
			guard !urlStrings.isEmpty else {
				return
			}
			await MainActor.run {
				for urlString in urlStrings where !ArticleImageContentBlocker.shared.isBlocked(urlString) {
					ArticleImageDownloader.shared.prefetch(urlString)
				}
			}
		}
	}
}

private extension ArticleImagePrefetcher {

	static func baseURLString(for article: Article) -> String? {
		article.link ?? article.feed?.homePageURL ?? article.feed?.url
	}
}

/// Pure, nonisolated extraction of absolute http(s) image URLs from article HTML.
/// Kept separate from ArticleImagePrefetcher so it can run off the main thread and
/// be unit-tested directly.
enum ArticleImageURLExtractor {

	struct Input: Sendable {
		let html: String
		let baseURLString: String?
	}

	/// Extract deduplicated absolute http(s) image URLs from a batch of article HTML.
	static func imageURLStrings(in inputs: [Input]) -> [String] {
		var results = [String]()
		var seen = Set<String>()
		for input in inputs {
			let baseURL = input.baseURLString.flatMap { URL(string: $0) }
			for urlString in imageURLStrings(in: input.html, baseURL: baseURL) where seen.insert(urlString).inserted {
				results.append(urlString)
			}
		}
		return results
	}

	/// Extract absolute http(s) image URLs from a single article's HTML.
	/// Prefers data-canonical-src (Feedbin proxy images) over src, mirroring main.js.
	static func imageURLStrings(in html: String, baseURL: URL?) -> [String] {
		let nsHTML = html as NSString
		let imgMatches = imgTagRegex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

		var results = [String]()
		var seen = Set<String>()

		for match in imgMatches {
			let tag = nsHTML.substring(with: match.range)
			let raw = firstCapture(in: tag, regex: canonicalSrcRegex) ?? firstCapture(in: tag, regex: srcRegex)
			guard let raw else {
				continue
			}
			let decoded = decodeHTMLEntities(raw)
			guard let absolute = absoluteHTTPURLString(decoded, baseURL: baseURL), seen.insert(absolute).inserted else {
				continue
			}
			results.append(absolute)
		}
		return results
	}

	/// Decode the handful of HTML entities that commonly appear in URL attribute values.
	/// Note: the resulting absolute URL string is what gets md5-keyed on disk. For an offline
	/// cache HIT it must match the string the scheme handler receives at render time, which is
	/// the browser's DOM-resolved `element.src`. For plain absolute URLs the two agree; complex
	/// relative URLs may diverge (Foundation's URL resolution vs. the browser's), in which case
	/// the prefetch simply misses and the image is fetched (and then cached) on first online view.
	static func decodeHTMLEntities(_ string: String) -> String {
		guard string.contains("&") else {
			return string
		}
		var result = string
		let namedEntities = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&#x27;": "'", "&#38;": "&", "&#x26;": "&", "&lt;": "<", "&gt;": ">"]
		for (entity, replacement) in namedEntities {
			result = result.replacingOccurrences(of: entity, with: replacement)
		}
		return result
	}

	static func absoluteHTTPURLString(_ src: String, baseURL: URL?) -> String? {
		let resolved: URL?
		if src.hasPrefix("//") {
			let scheme = baseURL?.scheme ?? "https"
			resolved = URL(string: "\(scheme):\(src)")
		} else {
			resolved = URL(string: src, relativeTo: baseURL)?.absoluteURL
		}
		guard let resolved, let originalScheme = resolved.scheme, originalScheme.lowercased() == "http" || originalScheme.lowercased() == "https" else {
			return nil
		}
		// Lowercase the scheme so the disk key matches the browser's DOM-resolved element.src
		// (which the scheme handler receives with a lowercased scheme) — otherwise an
		// uppercase-scheme URL would prefetch under a different key and miss on view.
		let lowercasedScheme = originalScheme.lowercased()
		return lowercasedScheme + resolved.absoluteString.dropFirst(originalScheme.count)
	}

	static func firstCapture(in string: String, regex: NSRegularExpression) -> String? {
		let nsString = string as NSString
		guard let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: nsString.length)), match.numberOfRanges > 1 else {
			return nil
		}
		let captureRange = match.range(at: 1)
		guard captureRange.location != NSNotFound else {
			return nil
		}
		return nsString.substring(with: captureRange)
	}

	// NSRegularExpression is Sendable and thread-safe for matching, so these can be shared
	// across the main thread and the background parse.
	static let imgTagRegex = try! NSRegularExpression(pattern: "<img\\b[^>]*>", options: [.caseInsensitive])
	static let srcRegex = try! NSRegularExpression(pattern: "\\bsrc\\s*=\\s*[\"']([^\"']+)[\"']", options: [.caseInsensitive])
	static let canonicalSrcRegex = try! NSRegularExpression(pattern: "\\bdata-canonical-src\\s*=\\s*[\"']([^\"']+)[\"']", options: [.caseInsensitive])
}
