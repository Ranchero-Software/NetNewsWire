//
//  AppDelegate+Scriptability.swift
//  NetNewsWire
//
//  Created by Olof Hellman on 2/7/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
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
import Articles

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

        let normalizedURLString = urlString.normalizedURL
        if !normalizedURLString.mayBeURL {
            return
        }

        DispatchQueue.main.async {

            self.addWebFeed(normalizedURLString)
        }
    }
}

class NetNewsWireCreateElementCommand : NSCreateCommand {
    override func performDefaultImplementation() -> Any? {
         let classDescription = self.createClassDescription
         if (classDescription.className == "webFeed") {
             return ScriptableWebFeed.handleCreateElement(command:self)
         } else if (classDescription.className == "folder") {
             return ScriptableFolder.handleCreateElement(command:self)
         }
         return nil
    }
}

/*
    NSDeleteCommand is kind of an oddball AppleScript command in that the command dispatch
    goes to the container of the object(s) to be deleted, and the container needs to
    figure out what to delete. In the code below, 'receivers' is the container object(s)
    and keySpecifier is the thing to delete, relative to the container(s).  Because there
    is ambiguity about whether specifiers are lists or single objects, the code switches
    based on which it is.
*/
class NetNewsWireDeleteCommand : NSDeleteCommand {

    /*
        delete(objectToDelete:, from container:)
        At this point in handling the command, we know what the container is.
        Here the code unravels the case of objectToDelete being a list or a single object,
        ultimately calling container.deleteElement(element) for each element to delete
    */
    func delete(objectToDelete:Any, from container:ScriptingObjectContainer) {
        if let objectList = objectToDelete as? [Any] {
            for nthObject in objectList {
                self.delete(objectToDelete:nthObject, from:container)
            }
        } else if let element = objectToDelete as? ScriptingObject {
            container.deleteElement(element)
        }
    }
    
    /*
        delete(specifier:, from container:)
        At this point in handling the command, the container could be a list or a single object,
        and what to delete is still an unresolved NSScriptObjectSpecifier.
        Here the code unravels the case of container being a list or a single object. Once the
        container(s) is known, it is possible to resolve the keySpecifier based on that container.
        After resolving, we call delete(objectToDelete:, from container:) with the container and
        the resolved objects
    */
    func delete(specifier:NSScriptObjectSpecifier, from container:Any) {
        if let containerList = container as? [Any] {
            for nthObject in containerList {
                self.delete(specifier:specifier, from:nthObject)
            }
        } else if let container = container as? ScriptingObjectContainer {
            if let resolvedObjects = specifier.objectsByEvaluating(withContainers:container) {
                self.delete(objectToDelete:resolvedObjects, from:container)
            }
        }
    }

    /*
        performDefaultImplementation()
        This is where handling the delete event starts. receiversSpecifier should be the container(s) of
        the item to be deleted. keySpecifier is the thing in that container(s) to be deleted
        The first step is to resolve the receiversSpecifier and then call delete(specifier:, from container:)
    */
    override func performDefaultImplementation() -> Any? {
         if let receiversSpecifier = self.receiversSpecifier {
             if let receiverObjects = receiversSpecifier.objectsByEvaluatingSpecifier {
                self.delete(specifier:self.keySpecifier, from:receiverObjects)
             } 
         }
         return nil
    }
}

class NetNewsWireExistsCommand : NSExistsCommand {

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
    }
}

