//
//  ArticleModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/2/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

import Foundation
import RSCore
import Account
import Articles

protocol ArticleModelDelegate: class {
	var articleModelWebViewProvider: WebViewProvider? { get }
	func findPrevArticle(_: ArticleModel, article: Article) -> Article?
	func findNextArticle(_: ArticleModel, article: Article) -> Article?
	func selectArticle(_: ArticleModel, article: Article)
}

class ArticleModel: ObservableObject {
	
	weak var delegate: ArticleModelDelegate?
	
	var webViewProvider: WebViewProvider? {
		return delegate?.articleModelWebViewProvider
	}
	
	// MARK: API
	
	func findPrevArticle(_ article: Article) -> Article? {
		return delegate?.findPrevArticle(self, article: article)
	}
	
	func findNextArticle(_ article: Article) -> Article? {
		return delegate?.findNextArticle(self, article: article)
	}
	
	func selectArticle(_ article: Article) {
		delegate?.selectArticle(self, article: article)
	}
	
}

