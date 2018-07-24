//
//  Author+Scriptability.swift
//  Evergreen
//
//  Created by Olof Hellman on 1/19/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import Foundation
import Account
import Articles

@objc(ScriptableAuthor)
class ScriptableAuthor: NSObject, UniqueIdScriptingObject {

    let author:Author
    let container:ScriptingObjectContainer
    
    init (_ author:Author, container:ScriptingObjectContainer) {
        self.author = author
        self.container = container
    }

    @objc(objectSpecifier)
    override var objectSpecifier: NSScriptObjectSpecifier? {
        let scriptObjectSpecifier = self.container.makeFormUniqueIDScriptObjectSpecifier(forObject:self)
        return (scriptObjectSpecifier)
    }

    // MARK: --- ScriptingObject protocol ---

    var scriptingKey: String {
        return "authors"
    }

    // MARK: --- UniqueIdScriptingObject protocol ---

    // I am not sure if account should prefer to be specified by name or by ID
    // but in either case it seems like the accountID would be used as the keydata, so I chose ID

    @objc(uniqueId)
    var scriptingUniqueId:Any {
        return author.authorID
    }
    
    // MARK: --- Scriptable properties ---
    
    @objc(url)
    var url:String  {
        return self.author.url ?? ""
    }
    
    @objc(name)
    var name:String  {
        return self.author.name ?? ""
    }

    @objc(avatarURL)
    var avatarURL:String  {
        return self.author.avatarURL ?? ""
    }

    @objc(emailAddress)
    var emailAddress:String  {
        return self.author.emailAddress ?? ""
    }
}
