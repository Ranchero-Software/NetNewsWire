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

extension NSApplication : ScriptingObjectContainer {

    // MARK: --- ScriptingObjectContainer protocol ---

    var scriptingClassDescription: NSScriptClassDescription {
        return NSApplication.shared.classDescription as! NSScriptClassDescription
    }

    func deleteElement(_ element:ScriptingObject) {
        print ("delete event not handled")
    }

    var scriptingKey: String {
        return "application"
    }
    
    @objc(currentArticle)
    func currentArticle() -> ScriptableArticle? {
        var scriptableArticle: ScriptableArticle?
        if let currentArticle = appDelegate.scriptingCurrentArticle {
            if let feed = currentArticle.feed {
                let scriptableFeed = ScriptableFeed(feed, container:self)
                scriptableArticle = ScriptableArticle(currentArticle, container:scriptableFeed)
            }
        }
        return scriptableArticle
    }

    @objc(selectedArticles)
    func selectedArticles() -> NSArray {
        let articles = appDelegate.scriptingSelectedArticles
        let scriptableArticles:[ScriptableArticle] = articles.compactMap { article in
            if let feed = article.feed  {
                let scriptableFeed = ScriptableFeed(feed, container:self)
                return ScriptableArticle(article, container:scriptableFeed)
            } else {
                return nil
            }
        }
        return scriptableArticles as NSArray
    }

    // MARK: --- scriptable elements ---

    @objc(accounts)
    func accounts() -> NSArray {
        let accounts = AccountManager.shared.accounts
        return accounts.map { ScriptableAccount($0) } as NSArray
    }
    
    @objc(valueInAccountsWithUniqueID:)
    func valueInAccounts(withUniqueID id:String) -> ScriptableAccount? {
        let accounts = AccountManager.shared.accounts
        guard let account = accounts.first(where:{$0.accountID == id}) else { return nil }
        return ScriptableAccount(account)
    }

    /*
        accessing feeds from the application object skips the 'account' containment hierarchy
        this allows a script like 'articles of feed "The Shape of Everything"' as a shorthand
        for  'articles of feed "The Shape of Everything" of account "On My Mac"'
    */  
      
    func allFeeds() -> [Feed] {
        let accounts = AccountManager.shared.accounts
        let emptyFeeds:[Feed] = []
        return accounts.reduce(emptyFeeds) { (result, nthAccount) -> [Feed] in
              let accountFeeds = Array(nthAccount.topLevelFeeds)
              return result + accountFeeds
        }
    }

    @objc(feeds)
    func feeds() -> NSArray {
        let feeds = self.allFeeds()
        return feeds.map { ScriptableFeed($0, container:self) } as NSArray
    }

    @objc(valueInFeedsWithUniqueID:)
    func valueInFeeds(withUniqueID id:String) -> ScriptableFeed? {
        let feeds = self.allFeeds()
        guard let feed = feeds.first(where:{$0.feedID == id}) else { return nil }
        return ScriptableFeed(feed, container:self)
    }
}


