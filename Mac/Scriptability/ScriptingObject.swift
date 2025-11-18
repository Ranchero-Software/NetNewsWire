//
//  ScriptingObject.swift
//  NetNewsWire
//
//  Created by Olof Hellman on 1/10/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import Foundation

@MainActor protocol ScriptingObject {
	@MainActor var objectSpecifier: NSScriptObjectSpecifier?  { get }
	@MainActor var scriptingKey: String { get }
}

@MainActor protocol NamedScriptingObject: ScriptingObject {
	@MainActor var name:String { get }
}

@MainActor protocol UniqueIDScriptingObject: ScriptingObject {
	@MainActor var scriptingUniqueID: Any { get }
}
