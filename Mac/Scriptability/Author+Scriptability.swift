//
//  Author+Scriptability.swift
//  NetNewsWire
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

    @objc(scriptingSpecifierDescriptor)
    func scriptingSpecifierDescriptor() -> NSScriptObjectSpecifier {
        return (self.objectSpecifier ?? NSScriptObjectSpecifier() )
    }

    // MARK: --- ScriptingObject protocol ---

    var scriptingKey: String {
        return "authors"
    }

    // MARK: --- UniqueIdScriptingObject protocol ---

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
