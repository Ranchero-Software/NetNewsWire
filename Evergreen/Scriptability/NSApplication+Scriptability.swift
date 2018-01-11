//
//  NSApplication+Scriptability.swift
//  Evergreen
//
//  Created by Olof Hellman on 1/8/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import Cocoa
import Account

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
    
}


