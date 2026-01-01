//
//  ArticleExtractor.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Secrets

public enum ArticleExtractorState: Sendable {
    case ready
    case processing
    case failedToParse
    case complete
	case cancelled
}

@MainActor protocol ArticleExtractorDelegate {
	func articleExtractionDidFail(with: Error)
	func articleExtractionDidComplete(extractedArticle: ExtractedArticle)
}

@MainActor final class ArticleExtractor {
	let articleLink: String
	let delegate: ArticleExtractorDelegate
	var article: ExtractedArticle?

	var state = ArticleExtractorState.ready
    private let url: URL
	private var dataTask: URLSessionDataTask?

	public init?(_ articleLink: String, delegate: ArticleExtractorDelegate) {
		self.articleLink = articleLink
		self.delegate = delegate

		let clientURL = "https://extract.feedbin.com/parser"
		let username = SecretKey.mercuryClientID
		let signature = articleLink.hmacUsingSHA1(key: SecretKey.mercuryClientSecret)

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
			Task { @MainActor in
				guard let self else {
					return
				}

				if let error = error {
					self.state = .failedToParse
					DispatchQueue.main.async {
						self.delegate.articleExtractionDidFail(with: error)
					}
					return
				}

				guard let data = data else {
					self.state = .failedToParse
					DispatchQueue.main.async {
						self.delegate.articleExtractionDidFail(with: URLError(.cannotDecodeContentData))
					}
					return
				}

				do {
					let decoder = JSONDecoder()
					decoder.dateDecodingStrategy = .iso8601
					let decodedArticle = try decoder.decode(ExtractedArticle.self, from: data)

					Task { @MainActor in
						self.article = decodedArticle
						if decodedArticle.content == nil {
							self.state = .failedToParse
							self.delegate.articleExtractionDidFail(with: URLError(.cannotDecodeContentData))
						} else {
							self.state = .complete
							self.delegate.articleExtractionDidComplete(extractedArticle: decodedArticle)
						}
					}
				} catch {
					self.state = .failedToParse
					Task { @MainActor in
						self.delegate.articleExtractionDidFail(with: error)
					}
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
