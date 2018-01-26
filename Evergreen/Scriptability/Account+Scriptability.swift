//
//  Account+Scriptability.swift
//  Evergreen
//
//  Created by Olof Hellman on 1/9/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import Cocoa
import Account
import Data

@objc(ScriptableAccount)
class ScriptableAccount: NSObject, UniqueIdScriptingObject, ScriptingObjectContainer {
    
    let account:Account
    init (_ account:Account) {
        self.account = account
    }
    
    @objc(objectSpecifier)
    override var objectSpecifier: NSScriptObjectSpecifier? {
        let myContainer = NSApplication.shared
        let scriptObjectSpecifier = myContainer.makeFormUniqueIDScriptObjectSpecifier(forObject:self)
        return (scriptObjectSpecifier)
    }
    
    // MARK: --- ScriptingObject protocol ---
    
    var scriptingKey: String {
        return "accounts"
    }

    // MARK: --- UniqueIdScriptingObject protocol ---
    
    // I am not sure if account should prefer to be specified by name or by ID
    // but in either case it seems like the accountID would be used as the keydata, so I chose ID
    
    var scriptingUniqueId:Any {
        return account.accountID
    }

    // MARK: --- ScriptingObjectContainer protocol ---
    
    var scriptingClassDescription: NSScriptClassDescription {
        return self.classDescription as! NSScriptClassDescription
    }

    // MARK: --- Scriptable elements ---
    
    @objc(feeds)
    var feeds:NSArray  {
        let feeds = account.children.flatMap { $0 as? Feed }
        return feeds.map { ScriptableFeed($0, container:self) } as NSArray
    }
    
    @objc(folders)
    var folders:NSArray  {
        let folders = account.children.flatMap { $0 as? Folder }
        return folders.map { ScriptableFolder($0, container:self) } as NSArray
    }
    
    // MARK: --- Scriptable properties ---

    @objc(contents)
    var contents:NSArray  {
        var contentsArray:[AnyObject] = []
        for child in account.children {
            if let aFeed = child as? Feed {
                contentsArray.append(ScriptableFeed(aFeed, container:self))
            } else if let aFolder = child as? Folder {
                contentsArray.append(ScriptableFolder(aFolder, container:self))
            }
        }
        return contentsArray as NSArray
    }

    @objc(opmlRepresentation)
    var opmlRepresentation:String  {
        return self.account.OPMLString(indentLevel:0)
    }

    @objc(accountType)
    var accountType:OSType {
        var osType:String = ""
        switch self.account.type {
        case .onMyMac:
                osType = "Locl"
        case .feedly:
                osType = "Fdly"
        case .feedbin:
                osType = "Fdbn"
        case .feedWrangler:
                osType = "FWrg"
        case .newsBlur:
                osType = "NBlr"
        }
        return osType.FourCharCode()
    }
}
