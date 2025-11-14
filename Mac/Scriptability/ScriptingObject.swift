//
//  ScriptingObject.swift
//  NetNewsWire
//
//  Created by Olof Hellman on 1/10/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import Foundation

@MainActor protocol ScriptingObject {
    var objectSpecifier: NSScriptObjectSpecifier?  { get }
    var scriptingKey: String { get }
}

@MainActor protocol NamedScriptingObject: ScriptingObject {
    var name:String { get }
}

@MainActor protocol UniqueIdScriptingObject: ScriptingObject {
	var scriptingUniqueId:Any { get }
}
