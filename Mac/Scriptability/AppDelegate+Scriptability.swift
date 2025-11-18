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

@MainActor protocol AppDelegateAppleEvents {
    func installAppleEventHandlers()
    func getURL(_ event: NSAppleEventDescriptor, _ withReplyEvent: NSAppleEventDescriptor)
}

@MainActor protocol ScriptingAppDelegate {
    var  scriptingCurrentArticle: Article?  {get}
    var  scriptingSelectedArticles: [Article]  {get}
    var  scriptingMainWindowController:ScriptingMainWindowController? {get}
}

// Wrapper to safely transfer non-Sendable values across isolation boundaries
// This is safe for AppleScript commands because they always execute on the main thread
private struct UnsafeSendable<T>: @unchecked Sendable {
    let value: T
}

extension AppDelegate: AppDelegateAppleEvents {

    // MARK: GetURL Apple Event

    func installAppleEventHandlers() {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(AppDelegate.getURL(_:_:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    @objc func getURL(_ event: NSAppleEventDescriptor, _ withReplyEvent: NSAppleEventDescriptor) {

        guard var urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            return
        }

		// Handle themes
		if urlString.hasPrefix("netnewswire://theme") {
			guard let comps = URLComponents(string: urlString),
				  let queryItems = comps.queryItems,
				  let themeURLString = queryItems.first(where: { $0.name == "url" })?.value else {
					  return
				  }

			if let themeURL = URL(string: themeURLString) {
				let request = URLRequest(url: themeURL)
				let task = URLSession.shared.downloadTask(with: request) { location, response, error in
					guard let location = location else {
						return
					}

					do {
						try ArticleThemeDownloader.shared.handleFile(at: location)
					} catch {
						NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error": error])
					}
				}
				task.resume()
			}
			return

		}


		// Special case URL with specific scheme handler x-netnewswire-feed: intended to ensure we open
		// it regardless of which news reader may be set as the default
		let nnwScheme = "x-netnewswire-feed:"
		if urlString.hasPrefix(nnwScheme) {
			urlString = urlString.replacingOccurrences(of: nnwScheme, with: "feed:")
		}

        let normalizedURLString = urlString.normalizedURL
        if !normalizedURLString.mayBeURL {
            return
        }

        DispatchQueue.main.async {

            self.addFeed(normalizedURLString)
        }
    }
}

final class NetNewsWireCreateElementCommand : NSCreateCommand {
	// AppleScript commands always execute on the main thread, so using assumeIsolated is safe
	// even though NSCreateCommand doesn't have concurrency annotations
	nonisolated override func performDefaultImplementation() -> Any? {
         let unsafeSelf = UnsafeSendable(value: self)
         let wrapped = MainActor.assumeIsolated { () -> UnsafeSendable<Any?> in
             let instance = unsafeSelf.value
             let classDescription: NSScriptClassDescription = instance.createClassDescription
             let command: NSCreateCommand = instance
             if (classDescription.className == "feed") {
                 return UnsafeSendable(value: ScriptableFeed.handleCreateElement(command:command))
             } else if (classDescription.className == "folder") {
                 return UnsafeSendable(value: ScriptableFolder.handleCreateElement(command:command))
             }
             return UnsafeSendable(value: nil)
         }
         return wrapped.value
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
final class NetNewsWireDeleteCommand : NSDeleteCommand {

    /*
        delete(objectToDelete:, from container:)
        At this point in handling the command, we know what the container is.
        Here the code unravels the case of objectToDelete being a list or a single object,
        ultimately calling container.deleteElement(element) for each element to delete
    */
	@MainActor func delete(objectToDelete:Any, from container:ScriptingObjectContainer) {
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
	@MainActor func delete(specifier:NSScriptObjectSpecifier, from container:Any) {
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
	// AppleScript commands always execute on the main thread, so using assumeIsolated is safe
	// even though NSDeleteCommand doesn't have concurrency annotations
	nonisolated override func performDefaultImplementation() -> Any? {
         let unsafeSelf = UnsafeSendable(value: self)
         MainActor.assumeIsolated {
             let instance = unsafeSelf.value
             if let receiverObjects = instance.receiversSpecifier?.objectsByEvaluatingSpecifier {
                instance.delete(specifier:instance.keySpecifier, from:receiverObjects)
             }
         }
         return nil
    }
}

final class NetNewsWireExistsCommand : NSExistsCommand {

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

