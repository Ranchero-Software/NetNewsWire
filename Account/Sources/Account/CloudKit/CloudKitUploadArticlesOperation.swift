//
//  CloudKitUploadArticlesOperation.swift
//  
//
//  Created by Maurice Parker on 11/13/22.
//

import Foundation
import RSCore
import Articles
import SyncDatabase

class CloudKitUploadArticlesOperation: MainThreadOperation, Logging {
	
	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "CloudKitUploadArticlesOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private weak var articlesZone: CloudKitArticlesZone?
	private let articles: Set<Article>
	
	public var error: Error?
	
	init(articlesZone: CloudKitArticlesZone, articles: Set<Article>) {
		self.articlesZone = articlesZone
		self.articles = articles
	}
	
	func run() {
		guard let articlesZone = articlesZone else {
			self.operationDelegate?.operationDidComplete(self)
			return
		}
		
		logger.debug("Uploading \(self.articles.count, privacy: .public) articles...")
		
		let statusUpdates = articles.compactMap { article in
			return CloudKitArticleStatusUpdate(articleID: article.articleID, statuses: [SyncStatus(article: article)], article: article)
		}
		
		articlesZone.modifyArticles(statusUpdates) { result in
			self.logger.debug("Done uploading articles.")
			switch result {
			case .success:
				self.operationDelegate?.operationDidComplete(self)
			case .failure(let error):
				self.error = error
				self.operationDelegate?.cancelOperation(self)
			}
		}
	}
	
}

extension SyncStatus {
	
	init(article: Article) {
		switch true {
		case article.status.starred:
			self.init(articleID: article.articleID, key: .starred, flag: true)
		case article.status.read:
			self.init(articleID: article.articleID, key: .read, flag: true)
		default:
			self.init(articleID: article.articleID, key: .read, flag: false)
		}
	}
	
}
