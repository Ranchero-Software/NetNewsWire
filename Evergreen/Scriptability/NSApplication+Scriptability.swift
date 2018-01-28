//
//  NSApplication+Scriptability.swift
//  Evergreen
//
//  Created by Olof Hellman on 1/8/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import Cocoa
import Account
import Data

extension NSApplication : ScriptingObjectContainer {
    
    var scriptingClassDescription: NSScriptClassDescription {
        return NSApplication.shared.classDescription as! NSScriptClassDescription
    }
    
    var scriptingKey: String {
        return "application"
    }
    
    @objc(accounts)
    func accounts() -> NSArray {
        let accounts = AccountManager.shared.accounts
        return accounts.map { ScriptableAccount($0) } as NSArray
    }
    
    /*
        accessing feeds from the application object skips the 'account' containment hierarchy
        this allows a script like 'articles of feed "The Shape of Everything"' as a shorthand
        for  'articles of feed "The Shape of Everything" of account "On My Mac"'
    */
    @objc(feeds)
    func feeds() -> NSArray {
        let accounts = AccountManager.shared.accounts
        let emptyFeeds:[Feed] = []
        let feeds = accounts.reduce(emptyFeeds) { (result, nthAccount) -> [Feed] in
              let accountFeeds = nthAccount.children.compactMap { $0 as? Feed }
              return result + accountFeeds
        }
        return feeds.map { ScriptableFeed($0, container:self) } as NSArray
    }
}


