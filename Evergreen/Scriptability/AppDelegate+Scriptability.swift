//
//  AppDelegate+Scriptability.swift
//  Evergreen
//
//  Created by Olof Hellman on 2/7/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

/*
    Note:  strictly, the AppDelegate doesn't appear as part of the scripting model,
    so this file is rather unlike the other Object+Scriptability.swift files.
    However, the AppDelegate object is the de facto scripting accessor for some
    application elements and properties.  For, example, the main window is accessed
    via the AppDelegate's MainWindowController, and the main window itself has
    selected feeds, selected articles and a current article.  This file supplies the glue to access
    these scriptable objects, while being completely separate from the core AppDelegate code,
*/

import Foundation
import Data

protocol AppDelegateAppleEvents {
    func installAppleEventHandlers()
    func getURL(_ event: NSAppleEventDescriptor, _ withReplyEvent: NSAppleEventDescriptor)
}

protocol ScriptingAppDelegate {
    var  scriptingCurrentArticle: Article?  {get}
    var  scriptingSelectedArticles: [Article]  {get}
    var  scriptingMainWindowController:ScriptingMainWindowController? {get}
}

extension AppDelegate : AppDelegateAppleEvents {
    
    // MARK: GetURL Apple Event

    func installAppleEventHandlers() {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(AppDelegate.getURL(_:_:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }
    
    @objc func getURL(_ event: NSAppleEventDescriptor, _ withReplyEvent: NSAppleEventDescriptor) {

        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            return
        }

        let normalizedURLString = urlString.rs_normalizedURL()
        if !normalizedURLString.rs_stringMayBeURL() {
            return
        }

        DispatchQueue.main.async {

            self.addFeed(normalizedURLString)
        }
    }
}

class EvergreenExistsCommand : NSExistsCommand {
    
    // cocoa default behavior doesn't work here, because of cases where we define an object's property
    // to be another object type.  e.g., 'permalink of the current article' parses as
    //    <property> of <property> of <top level object>
    // cocoa would send the top level object (the app) a doesExist message for a nested property, and
    // it errors out because it doesn't know how to handle that
    // What we do instead is simply see if the defaultImplementation errors, and if it does, the object
    // must not exist.  Otherwise, we return the result of the defaultImplementation
    // The wrinkle is that it is possible that the direct object is a list, so we need to
    // handle that case as well
    
    override func performDefaultImplementation() -> Any? {
         guard let result = super.performDefaultImplementation() else { return NSNumber(booleanLiteral:false) }
         return result
        // return NSNumber(booleanLiteral:true)
         //  scriptingContainer.handleDoObjectsExist(command:self)
    }
}

