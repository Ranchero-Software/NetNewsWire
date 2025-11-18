//
//  ScriptingObjectContainer.swift
//  Account
//
//  Created by Olof Hellman on 1/9/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import AppKit
import Account

protocol ScriptingObjectContainer: ScriptingObject {
	var scriptingClassDescription:NSScriptClassDescription { get }
	func deleteElement(_ element:ScriptingObject)
}

extension ScriptingObjectContainer {

	nonisolated func makeFormNameScriptObjectSpecifier(forObject object:NamedScriptingObject) -> NSScriptObjectSpecifier? {
        let containerClassDescription = self.scriptingClassDescription
        let containerScriptObjectSpecifier = self.objectSpecifier
        let scriptingKey = object.scriptingKey
        let name = object.name
        let specifier = NSNameSpecifier(containerClassDescription:containerClassDescription,
                                        containerSpecifier:containerScriptObjectSpecifier, key:scriptingKey, name:name)
        return specifier
    }

	nonisolated func makeFormUniqueIDScriptObjectSpecifier(forObject object:UniqueIDScriptingObject) -> NSScriptObjectSpecifier? {
        let containerClassDescription = self.scriptingClassDescription
        let containerScriptObjectSpecifier = self.objectSpecifier
        let scriptingKey = object.scriptingKey
        let uniqueId = object.scriptingUniqueID
        let specifier = NSUniqueIDSpecifier(containerClassDescription:containerClassDescription,
                                            containerSpecifier:containerScriptObjectSpecifier, key:scriptingKey, uniqueID: uniqueId)
        return specifier
    }
}

