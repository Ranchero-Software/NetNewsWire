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
@MainActor final class ScriptableAuthor: NSObject, UniqueIDScriptingObject {
    let author: Author
    nonisolated(unsafe) let container: ScriptingObjectContainer

    init(_ author: Author, container: ScriptingObjectContainer) {
        self.author = author
        self.container = container
    }

    @objc(objectSpecifier)
	nonisolated override var objectSpecifier: NSScriptObjectSpecifier? {
        let scriptObjectSpecifier = container.makeFormUniqueIDScriptObjectSpecifier(forObject: self)
        return scriptObjectSpecifier
    }

    @objc(scriptingSpecifierDescriptor)
    func scriptingSpecifierDescriptor() -> NSScriptObjectSpecifier {
        objectSpecifier ?? NSScriptObjectSpecifier()
    }

    // MARK: - ScriptingObject protocol

    nonisolated var scriptingKey: String {
        "authors"
    }

    // MARK: - UniqueIdScriptingObject protocol

    @objc(uniqueId)
    nonisolated var scriptingUniqueID: Any {
        author.authorID
    }

    // MARK: - Scriptable properties

    @objc(url)
    var url: String {
        author.url ?? ""
    }

    @objc(name)
    var name: String {
        author.name ?? ""
    }

    @objc(avatarURL)
    var avatarURL: String {
        author.avatarURL ?? ""
    }

    @objc(emailAddress)
    var emailAddress: String {
        author.emailAddress ?? ""
    }
}
