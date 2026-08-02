//
//  ArticleImageSchemeHandler.swift
//  NetNewsWire
//
//  Serves article-body images to the web view from the offline cache.
//
//  main.js rewrites each <img src> to nnwimage://cache/?u=<encoded-original-url>
//  (only when offline caching is enabled). This handler decodes the original URL,
//  serves the bytes from ArticleImageDownloader (memory → disk → network), and
//  returns them to WebKit. When offline and uncached, the request fails and the
//  web view shows a broken image — the rest of the article still renders.
//

import Foundation
import WebKit
import Images

@MainActor final class ArticleImageSchemeHandler: NSObject, WKURLSchemeHandler {

	static let scheme = "nnwimage"
	static let shared = ArticleImageSchemeHandler()

	/// Tasks currently in flight. A task is "ours to complete" only while its ID is in this set.
	/// We must never call back into a task WebKit has stopped (it throws an Objective-C exception).
	/// Membership is positive (insert on start, remove on stop or completion), so a stale entry
	/// can't survive to collide with a later task that reuses the same object address.
	private var activeTasks = Set<ObjectIdentifier>()

	func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {

		let taskID = ObjectIdentifier(urlSchemeTask)

		// The handler is registered unconditionally (see WebViewConfiguration), but only
		// main.js's rewrite and the prefetcher are gated on the setting — this scheme is
		// otherwise reachable directly from article HTML (e.g. a feed embedding
		// "nnwimage://cache/?u=..." itself). Refuse to fetch or cache anything unless the
		// user has actually opted in, so the setting's off-state is a real guarantee.
		guard AppDefaults.shared.cacheImagesForOffline else {
			urlSchemeTask.didFailWithError(URLError(.resourceUnavailable))
			return
		}

		guard let requestURL = urlSchemeTask.request.url,
			  let originalURL = Self.originalURLString(from: requestURL) else {
			urlSchemeTask.didFailWithError(URLError(.badURL))
			return
		}

		// The web view's own content blocker doesn't apply to this URLSession-backed fetch,
		// so apply the same block list here — otherwise routing images through the cache would
		// bypass tracker/ad blocking.
		guard !ArticleImageContentBlocker.shared.isBlocked(originalURL) else {
			urlSchemeTask.didFailWithError(URLError(.resourceUnavailable))
			return
		}

		activeTasks.insert(taskID)

		Task { @MainActor in
			let data = await ArticleImageDownloader.shared.data(for: originalURL, allowNetwork: true)

			// If the task was stopped while we were fetching, it's no longer in activeTasks.
			// Calling into a stopped task throws an Objective-C exception, so bail out cleanly.
			guard activeTasks.remove(taskID) != nil else {
				return
			}

			guard let data else {
				urlSchemeTask.didFailWithError(URLError(.resourceUnavailable))
				return
			}

			let mimeType = Self.mimeType(for: data)
			let response = URLResponse(url: requestURL, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)
			urlSchemeTask.didReceive(response)
			urlSchemeTask.didReceive(data)
			urlSchemeTask.didFinish()
		}
	}

	func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
		activeTasks.remove(ObjectIdentifier(urlSchemeTask))
	}
}

private extension ArticleImageSchemeHandler {

	/// Pull the percent-encoded original URL out of nnwimage://cache/?u=<encoded>.
	static func originalURLString(from url: URL) -> String? {
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
			  components.host == "cache", // only nnwimage://cache/?u=... is a cache request
			  let value = components.queryItems?.first(where: { $0.name == "u" })?.value,
			  !value.isEmpty else {
			return nil
		}
		return value
	}

	/// Sniff the image type from the leading bytes so WebKit gets a correct Content-Type.
	/// A wrong type can keep an otherwise-valid cached image from rendering offline.
	static func mimeType(for data: Data) -> String {
		let bytes = [UInt8](data.prefix(12))
		guard let first = bytes.first else {
			return "application/octet-stream"
		}

		// ISO base media (ftyp) container — AVIF and HEIC share it; distinguish by brand.
		if bytes.count >= 12, bytes[4] == 0x66, bytes[5] == 0x74, bytes[6] == 0x79, bytes[7] == 0x70 {
			let brand = String(bytes: bytes[8..<12], encoding: .ascii) ?? ""
			if brand.hasPrefix("avif") || brand.hasPrefix("avis") {
				return "image/avif"
			}
			if brand.hasPrefix("heic") || brand.hasPrefix("heix") || brand.hasPrefix("mif1") || brand.hasPrefix("msf1") {
				return "image/heic"
			}
		}
		// ICO
		if bytes.count >= 4, bytes[0] == 0x00, bytes[1] == 0x00, bytes[2] == 0x01, bytes[3] == 0x00 {
			return "image/x-icon"
		}

		switch first {
		case 0xFF:
			return "image/jpeg"
		case 0x89:
			return "image/png"
		case 0x47:
			return "image/gif"
		case 0x42:
			return "image/bmp"
		case 0x49, 0x4D:
			return "image/tiff"
		case 0x52: // "RIFF" → WebP
			return "image/webp"
		case 0x3C: // "<" → SVG/XML
			return "image/svg+xml"
		default:
			return "application/octet-stream"
		}
	}
}
