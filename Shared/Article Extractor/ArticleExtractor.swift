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

public enum ArticleExtractorState {
    case ready
    case processing
    case failedToParse
    case complete
	case cancelled
}

protocol ArticleExtractorDelegate {
    func articleExtractionDidFail(with: Error)
    func articleExtractionDidComplete(extractedArticle: ExtractedArticle)
}

class ArticleExtractor {
	
	private var dataTask: URLSessionDataTask? = nil
    
    var state: ArticleExtractorState!
    var article: ExtractedArticle?
    var delegate: ArticleExtractorDelegate?
	var articleLink: String?
	
    private var url: URL!
    
    public init?(_ articleLink: String) {
		self.articleLink = articleLink
		
		let clientURL = "https://extract.feedbin.com/parser"
		let username = SecretsManager.provider.mercuryClientId
		let signiture = articleLink.hmacUsingSHA1(key: SecretsManager.provider.mercuryClientSecret)
		
		if let base64URL = articleLink.data(using: .utf8)?.base64EncodedString() {
			let fullURL = "\(clientURL)/\(username)/\(signiture)?base64_url=\(base64URL)"
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
            
            guard let self = self else { return }
            
            if let error = error {
                self.state = .failedToParse
                DispatchQueue.main.async {
                    self.delegate?.articleExtractionDidFail(with: error)
                }
                return
            }
            
            guard let data = data else {
                self.state = .failedToParse
                DispatchQueue.main.async {
					self.delegate?.articleExtractionDidFail(with: URLError(.cannotDecodeContentData))
                }
                return
            }
 
            do {
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .iso8601
				self.article = try decoder.decode(ExtractedArticle.self, from: data)
				
                DispatchQueue.main.async {
					if self.article?.content == nil {
						self.state = .failedToParse
						self.delegate?.articleExtractionDidFail(with: URLError(.cannotDecodeContentData))
					} else {
						self.state = .complete
						self.delegate?.articleExtractionDidComplete(extractedArticle: self.article!)
					}
                }
            } catch {
                self.state = .failedToParse
                DispatchQueue.main.async {
                    self.delegate?.articleExtractionDidFail(with: error)
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
