//
//  ArticleImageSchemeHandler.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/27/26.
//

import Foundation
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
import WebKit
import RSCore
import Images

/// Serves `ArticleRenderer.articleImageScheme` URLs from the timeline’s copy of the image,
/// downloading it first when needed, so the image is downloaded once.
///
/// Fails for images ImageIO can’t identify, so the page can fall back to the original URL.
///
/// Routed URLs are signed with a key made at launch, and unsigned or wrongly signed requests fail.
/// So feed content and script can’t use the scheme to download other images, which would
/// get past content blocking and fill the shared cache.
@MainActor final class ArticleImageSchemeHandler: NSObject, WKURLSchemeHandler {

	/// Never saved, so routed URLs are good only for this run of the app.
	private static let signingKey = SymmetricKey(size: .bits256)
	/// Percent-encoding leaves only alphanumerics in the encoded image URL, so this can’t appear in it.
	private static let signatureSeparator: Character = "?"

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
				imageData = try await ThumbnailDownloader.shared.fullSizeImageData(url: imageURL, articleTitle: nil)
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

	/// The scheme, the percent-encoded image URL, and its signature.
	static func routedURLString(_ imageURL: String) -> String? {
		guard let encodedURL = imageURL.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
			return nil
		}
		return "\(ArticleRenderer.articleImageScheme):\(encodedURL)\(signatureSeparator)\(signature(imageURL))"
	}

	/// The image URL, or nil when `requestURL` wasn’t made by `routedURLString` in this run of the app.
	static func imageURL(_ requestURL: URL) -> String? {
		guard let scheme = requestURL.scheme else {
			return nil
		}
		let routedPart = requestURL.absoluteString.dropFirst(scheme.count + 1)
		let parts = routedPart.split(separator: signatureSeparator, maxSplits: 1)
		guard parts.count == 2, let imageURL = parts[0].removingPercentEncoding, !imageURL.isEmpty, parts[1] == signature(imageURL) else {
			return nil
		}
		return imageURL
	}
}

private extension ArticleImageSchemeHandler {

	static func signature(_ imageURL: String) -> String {
		let authenticationCode = HMAC<SHA256>.authenticationCode(for: Data(imageURL.utf8), using: signingKey)
		return Data(authenticationCode).hexadecimalString ?? ""
	}

	static func mimeType(_ data: Data) -> String? {
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil), let typeIdentifier = CGImageSourceGetType(imageSource) else {
			return nil
		}
		return UTType(typeIdentifier as String)?.preferredMIMEType
	}
}
