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
            if let feed = currentArticle.webFeed {
                let scriptableFeed = ScriptableWebFeed(feed, container:self)
                scriptableArticle = ScriptableArticle(currentArticle, container:scriptableFeed)
            }
        }
        return scriptableArticle
    }

    @objc(selectedArticles)
    func selectedArticles() -> NSArray {
        let articles = appDelegate.scriptingSelectedArticles
        let scriptableArticles:[ScriptableArticle] = articles.compactMap { article in
            if let feed = article.webFeed  {
                let scriptableFeed = ScriptableWebFeed(feed, container:self)
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
        let accounts = AccountManager.shared.activeAccounts
        guard let account = accounts.first(where:{$0.accountID == id}) else { return nil }
        return ScriptableAccount(account)
    }

    /*
        accessing feeds from the application object skips the 'account' containment hierarchy
        this allows a script like 'articles of feed "The Shape of Everything"' as a shorthand
        for  'articles of feed "The Shape of Everything" of account "On My Mac"'
    */  
      
    func allWebFeeds() -> [WebFeed] {
        let accounts = AccountManager.shared.activeAccounts
        let emptyFeeds:[WebFeed] = []
        return accounts.reduce(emptyFeeds) { (result, nthAccount) -> [WebFeed] in
              let accountFeeds = Array(nthAccount.topLevelWebFeeds)
              return result + accountFeeds
        }
    }

    @objc(webFeeds)
    func webFeeds() -> NSArray {
        let webFeeds = self.allWebFeeds()
        return webFeeds.map { ScriptableWebFeed($0, container:self) } as NSArray
    }

    @objc(valueInWebFeedsWithUniqueID:)
    func valueInWebFeeds(withUniqueID id:String) -> ScriptableWebFeed? {
        let webFeeds = self.allWebFeeds()
        guard let webFeed = webFeeds.first(where:{$0.webFeedID == id}) else { return nil }
        return ScriptableWebFeed(webFeed, container:self)
    }
}


