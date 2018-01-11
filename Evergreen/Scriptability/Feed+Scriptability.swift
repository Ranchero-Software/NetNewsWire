//
//  Feed+Scriptability.swift
//  Evergreen
//
//  Created by Olof Hellman on 1/10/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import Foundation
import Account
import Data

@objc(ScriptableFeed)
class ScriptableFeed: NSObject, UniqueIdScriptingObject {

    let feed:Feed
    let container:ScriptingObjectContainer
    
    init (_ feed:Feed, container:ScriptingObjectContainer) {
        self.feed = feed
        self.container = container
    }

    @objc(objectSpecifier)
    override var objectSpecifier: NSScriptObjectSpecifier? {
        let scriptObjectSpecifier = self.container.makeFormUniqueIDScriptObjectSpecifier(forObject:self)
        return (scriptObjectSpecifier)
    }

    // MARK: --- ScriptingObject protocol ---

    var scriptingKey: String {
        return "feeds"
    }

    // MARK: --- UniqueIdScriptingObject protocol ---

    // I am not sure if account should prefer to be specified by name or by ID
    // but in either case it seems like the accountID would be used as the keydata, so I chose ID

    var scriptingUniqueId:Any {
        return feed.feedID
    }
    
    // MARK: --- Scriptable properties ---
    
    @objc(url)
    var url:String  {
        return self.feed.url
    }
    
    @objc(uniqueId)
    var uniqueId:String  {
        return self.feed.feedID
    }
    
    @objc(name)
    var name:String  {
        return self.feed.name ?? ""
    }

}
