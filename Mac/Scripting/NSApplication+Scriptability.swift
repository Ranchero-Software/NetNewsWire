//
//  NSApplication+Scriptability.swift
//  NetNewsWire
//
//  Created by Olof Hellman on 1/8/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import AppKit
import Account
import Articles

extension NSApplication: @preconcurrency ScriptingObjectContainer {
    // MARK: - ScriptingObjectContainer protocol
	
    nonisolated var scriptingClassDescription: NSScriptClassDescription {
        return self.classDescription as! NSScriptClassDescription
    }

    func deleteElement(_ element: ScriptingObject) {
        print ("delete event not handled")
    }

    nonisolated var scriptingKey: String {
        return "application"
    }

    @objc(currentArticle)
    func currentArticle() -> ScriptableArticle? {
        var scriptableArticle: ScriptableArticle?
        if let currentArticle = appDelegate.scriptingCurrentArticle {
            if let feed = currentArticle.feed,
               let scriptableFeed = ScriptableFeed.scriptableFeed(for: feed) {
                scriptableArticle = ScriptableArticle(currentArticle, container: scriptableFeed)
            }
        }
        return scriptableArticle
    }

    @objc(selectedArticles)
    func selectedArticles() -> NSArray {
        let articles = appDelegate.scriptingSelectedArticles
        let scriptableArticles: [ScriptableArticle] = articles.compactMap { article in
            if let feed = article.feed,
               let scriptableFeed = ScriptableFeed.scriptableFeed(for: feed) {
                return ScriptableArticle(article, container: scriptableFeed)
            } else {
                return nil
            }
        }
        return scriptableArticles as NSArray
    }

    @objc(countOfSelectedArticles)
    func countOfSelectedArticles() -> Int {
        return appDelegate.scriptingSelectedArticles.count
    }

    @objc(objectInSelectedArticlesAtIndex:)
    func objectInSelectedArticlesAtIndex(_ index: Int) -> ScriptableArticle? {
        let articles = appDelegate.scriptingSelectedArticles
        guard index >= 0 && index < articles.count else { return nil }
        let article = articles[index]

        if let feed = article.feed,
           let scriptableFeed = ScriptableFeed.scriptableFeed(for: feed) {
            return ScriptableArticle(article, container: scriptableFeed)
        } else {
            return nil
        }
    }

    // MARK: --- scriptable elements ---

    @objc(accounts)
    func accounts() -> NSArray {
        let accounts = AccountManager.shared.accounts
        return accounts.map { ScriptableAccount($0) } as NSArray
    }

    @objc(countOfAccounts)
    func countOfAccounts() -> Int {
        return AccountManager.shared.accounts.count
    }

    @objc(objectInAccountsAtIndex:)
    func objectInAccountsAtIndex(_ index: Int) -> ScriptableAccount? {
        let accounts = Array(AccountManager.shared.accounts)
        guard index >= 0 && index < accounts.count else { return nil }
        return ScriptableAccount(accounts[index])
    }

    @objc(valueInAccountsWithUniqueID:)
    func valueInAccounts(withUniqueID id: String) -> ScriptableAccount? {
        let accounts = AccountManager.shared.accounts
		guard let account = accounts.first(where: { $0.accountID == id }) else {
			return nil
		}
        return ScriptableAccount(account)
    }

    /*
        accessing feeds from the application object skips the 'account' containment hierarchy
        this allows a script like 'articles of feed "The Shape of Everything"' as a shorthand
        for  'articles of feed "The Shape of Everything" of account "On My Mac"'
    */  

    func allFeeds() -> [Feed] {
        let accounts = AccountManager.shared.activeAccounts
        let emptyFeeds: [Feed] = []
        return accounts.reduce(emptyFeeds) { (result, nthAccount) -> [Feed] in
              let accountFeeds = Array(nthAccount.topLevelFeeds)
              return result + accountFeeds
        }
    }

    @objc(feeds)
    func feeds() -> NSArray {
        allFeeds().map { ScriptableFeed($0, container: self) } as NSArray
    }

    @objc(countOfFeeds)
    func countOfFeeds() -> Int {
        allFeeds().count
    }

    @objc(objectInFeedsAtIndex:)
    func objectInFeedsAtIndex(_ index: Int) -> ScriptableFeed? {
        let feeds = allFeeds()
		guard index >= 0 && index < feeds.count else {
			return nil
		}
        return ScriptableFeed(feeds[index], container: self)
    }

    @objc(valueInFeedsWithUniqueID:)
    func valueInFeeds(withUniqueID id: String) -> ScriptableFeed? {
        let feeds = allFeeds()
		guard let feed = feeds.first(where: { $0.feedID == id} ) else {
			return nil
		}
        return ScriptableFeed(feed, container: self)
    }
}
