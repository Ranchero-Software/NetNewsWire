//
//  ArticleExtractor.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import FoundationExtras

public enum ArticleExtractorState: Sendable {
    case ready
    case processing
    case failedToParse
    case complete
	case cancelled
}

public protocol ArticleExtractorDelegate {

	@MainActor func articleExtractionDidFail(with: Error)
	@MainActor func articleExtractionDidComplete(extractedArticle: ExtractedArticle)
}

@MainActor public final class ArticleExtractor {

	public var state: ArticleExtractorState!
	public var article: ExtractedArticle?
	public var delegate: ArticleExtractorDelegate?
	public let articleLink: String?

	private var dataTask: URLSessionDataTask? = nil
	private let url: URL!

	public init?(_ articleLink: String, clientID: String, clientSecret: String) {
		self.articleLink = articleLink
		
		let clientURL = "https://extract.feedbin.com/parser"
		let username = clientID
		let signature = articleLink.hmacUsingSHA1(key: clientSecret)

		if let base64URL = articleLink.data(using: .utf8)?.base64EncodedString() {
			let fullURL = "\(clientURL)/\(username)/\(signature)?base64_url=\(base64URL)"
			if let url = URL(string: fullURL) {
				self.url = url
				return
			}
		}
		
		return nil
    }
    
    public func process() {

		state = .processing

		dataTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in

			Task { @MainActor [weak self] in
				guard let self else {
					return
				}

				if let error {
					self.noteDidFail(error: error)
					return
				}

				guard let data else {
					self.noteDidFail(error: URLError(.cannotDecodeContentData))
					return
				}

				do {
					let article = try decodeArticle(data: data)
					self.article = article

					if article.content == nil {
						self.noteDidFail(error: URLError(.cannotDecodeContentData))
					} else {
						self.noteDidComplete(article: article)
					}
				} catch {
					self.noteDidFail(error: error)
				}
			}
		}

        dataTask!.resume()
    }
	
	public func cancel() {
		state = .cancelled
		dataTask?.cancel()
	}
}

private extension ArticleExtractor {

	func decodeArticle(data: Data) throws -> ExtractedArticle {

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601

		let article = try decoder.decode(ExtractedArticle.self, from: data)
		return article
	}

	func noteDidFail(error: Error) {

		state = .failedToParse
		delegate?.articleExtractionDidFail(with: error)
	}

	func noteDidComplete(article: ExtractedArticle) {

		state = .complete
		delegate?.articleExtractionDidComplete(extractedArticle: article)
	}
}
