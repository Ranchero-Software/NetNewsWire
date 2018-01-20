//
//  Folder+Scriptability.swift
//  Evergreen
//
//  Created by Olof Hellman on 1/10/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import Foundation
import Account

@objc(ScriptableFolder)
class ScriptableFolder: NSObject, UniqueIdScriptingObject {

    let folder:Folder
    let container:ScriptingObjectContainer

    init (_ folder:Folder, container:ScriptingObjectContainer) {
        self.folder = folder
        self.container = container
    }

    @objc(objectSpecifier)
    override var objectSpecifier: NSScriptObjectSpecifier? {
        let scriptObjectSpecifier = self.container.makeFormUniqueIDScriptObjectSpecifier(forObject:self)
        return (scriptObjectSpecifier)
    }

    // MARK: --- ScriptingObject protocol ---

    var scriptingKey: String {
        return "folders"
    }

    // MARK: --- UniqueIdScriptingObject protocol ---

    // I am not sure if account should prefer to be specified by name or by ID
    // but in either case it seems like the accountID would be used as the keydata, so I chose ID

    var scriptingUniqueId:Any {
        return folder.folderID
    }
    
    // MARK: --- Scriptable properties ---
    
    @objc(uniqueId)
    var uniqueId:Int  {
        return self.folder.folderID
    }
    
    @objc(name)
    var name:String  {
        return self.folder.name ?? ""
    }

    @objc(opmlRepresentation)
    var opmlRepresentation:String  {
        return self.folder.OPMLString(indentLevel:0)
    }

}
