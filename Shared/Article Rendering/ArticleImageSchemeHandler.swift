//
//  ArticleImageSchemeHandler.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/27/26.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers
import WebKit
import Images

/// Serves `ArticleRenderer.articleImageScheme` URLs from the timeline’s copy of the image,
/// downloading it first when needed, so the image is downloaded once.
///
/// Fails for images ImageIO can’t identify, so the page can fall back to the original URL.
@MainActor final class ArticleImageSchemeHandler: NSObject, WKURLSchemeHandler {

	private var runningTaskIDs = Set<ObjectIdentifier>() // Stopped tasks must not be called again

	func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
		guard let requestURL = urlSchemeTask.request.url, let imageURL = Self.imageURL(requestURL) else {
			urlSchemeTask.didFailWithError(URLError(.badURL))
			return
		}

		let taskID = ObjectIdentifier(urlSchemeTask)
		runningTaskIDs.insert(taskID)

		Task { @MainActor in
			var imageData: Data?
			var downloadError: Error?
			do {
				imageData = try await ArticleThumbnailFinder.shared.fullSizeImageData(url: imageURL, articleTitle: nil)
			} catch {
				downloadError = error
			}

			guard runningTaskIDs.remove(taskID) != nil else {
				return
			}
			guard let imageData, let mimeType = Self.mimeType(imageData) else {
				urlSchemeTask.didFailWithError(downloadError ?? URLError(.cannotDecodeContentData))
				return
			}
			let response = URLResponse(url: requestURL, mimeType: mimeType, expectedContentLength: imageData.count, textEncodingName: nil)
			urlSchemeTask.didReceive(response)
			urlSchemeTask.didReceive(imageData)
			urlSchemeTask.didFinish()
		}
	}

	func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
		runningTaskIDs.remove(ObjectIdentifier(urlSchemeTask))
	}
}

private extension ArticleImageSchemeHandler {

	/// The percent-encoded original URL follows the scheme.
	static func imageURL(_ requestURL: URL) -> String? {
		guard let scheme = requestURL.scheme else {
			return nil
		}
		let encodedURL = requestURL.absoluteString.dropFirst(scheme.count + 1)
		guard let imageURL = encodedURL.removingPercentEncoding, !imageURL.isEmpty else {
			return nil
		}
		return imageURL
	}

	static func mimeType(_ data: Data) -> String? {
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil), let typeIdentifier = CGImageSourceGetType(imageSource) else {
			return nil
		}
		return UTType(typeIdentifier as String)?.preferredMIMEType
	}
}
