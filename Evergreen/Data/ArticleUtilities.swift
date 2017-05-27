//
//  ArticleUtilities.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/25/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import DataModel

// These handle multiple accounts.

func markArticles(_ articles: NSSet, statusKey: ArticleStatusKey, flag: Bool) {
	
	let d: [String: NSSet] = accountAndArticlesDictionary(articles)
	
	d.keys.forEach { (oneAccountIdentifier) in
		
		guard let oneAccountArticles = d[oneAccountIdentifier], let oneAccount = accountWithIdentifier(oneAccountIdentifier) else {
			return
		}
		
		oneAccount.markArticles(oneAccountArticles, statusKey: statusKey, flag: flag)
	}
}

private func accountAndArticlesDictionary(_ articles: NSSet) -> [String: NSSet] {
    
    var d = [String: NSMutableSet]()
	
	articles.forEach { (oneObject) in

		guard let oneArticle = oneObject as? Article else {
			return
		}
		guard let oneAccountIdentifier = oneArticle.account?.identifier else {
			return
		}

		let oneArticleSet: NSMutableSet = d[oneAccountIdentifier] ?? NSMutableSet()
		oneArticleSet.add(oneArticle)
		d[oneAccountIdentifier] = oneArticleSet
	}

    return d
}

private func accountWithIdentifier(_ identifier: String) -> Account? {
    
    return AccountManager.sharedInstance.existingAccountWithIdentifier(identifier)
}

func preferredLink(for article: Article) -> String? {
	
	if let s = article.permalink {
		return s
	}
	return article.link
}

