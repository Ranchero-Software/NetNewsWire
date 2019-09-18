//
//  ArticleExtractor.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

public enum ArticleExtractorState {
    case ready
    case processing
    case failedToParse
    case complete
}

protocol ArticleExtractorDelegate {
    func articleExtractionDidFail(with: Error)
    func articleExtractionDidComplete(extractedArticle: ExtractedArticle)
}

enum ArticleExtractorError: Error {
    case UnableToParseHTML
    case MissingURL
    case UnableToLoadURL
}

class ArticleExtractor {
    
    var state: ArticleExtractorState!
    var article: ExtractedArticle?
    var delegate: ArticleExtractorDelegate?
	var articleLink: String?
	
    private var url: URL!
    
    public init?(_ articleLink: String) {
		self.articleLink = articleLink
		
		let clientURL = ArticleExtractorConfig.Mercury.clientURL
		let username = ArticleExtractorConfig.Mercury.clientId
		let signiture = articleLink.hmacUsingSHA1(key: ArticleExtractorConfig.Mercury.clientSecret)
		
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

        let dataTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            
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
                    self.delegate?.articleExtractionDidFail(with: ArticleExtractorError.UnableToLoadURL)
                }
                return
            }
 
            do {
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .iso8601
				self.article = try decoder.decode(ExtractedArticle.self, from: data)
				
				self.state = .complete
                DispatchQueue.main.async {
					self.delegate?.articleExtractionDidComplete(extractedArticle: self.article!)
                }
            } catch {
                self.state = .failedToParse
                DispatchQueue.main.async {
                    self.delegate?.articleExtractionDidFail(with: error)
                }
            }
            
        }
        
        dataTask.resume()
        
    }
    
}
