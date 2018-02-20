//
//  Feed+Scriptability.swift
//  Evergreen
//
//  Created by Olof Hellman on 1/10/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import Foundation
import RSParser
import Account
import Data

@objc(ScriptableFeed)
class ScriptableFeed: NSObject, UniqueIdScriptingObject, ScriptingObjectContainer{

    let feed:Feed
    let container:ScriptingObjectContainer
    
    init (_ feed:Feed, container:ScriptingObjectContainer) {
        self.feed = feed
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
        return "feeds"
    }

    // MARK: --- UniqueIdScriptingObject protocol ---

    // I am not sure if account should prefer to be specified by name or by ID
    // but in either case it seems like the accountID would be used as the keydata, so I chose ID

    var scriptingUniqueId:Any {
        return feed.feedID
    }

    // MARK: --- ScriptingObjectContainer protocol ---
    
    var scriptingClassDescription: NSScriptClassDescription {
        return self.classDescription as! NSScriptClassDescription
    }
    

    // MARK: --- Create Element Handlers ---

    class func parsedFeedForURL(_ urlString:String, _ completionHandler: @escaping (_ parsedFeed: ParsedFeed?) -> Void) {
        guard let url = URL(string: urlString) else {
            completionHandler(nil)
            return
        }
        InitialFeedDownloader.download(url) { (parsedFeed) in
            completionHandler(parsedFeed)
        }
    }
    
    class func urlForNewFeed(arguments:[String:Any]) -> String?  {
        var url:String?
        if let withDataParam = arguments["ObjectData"] {
            if let objectDataDescriptor = withDataParam as? NSAppleEventDescriptor {
                url = objectDataDescriptor.stringValue
            }
        } else if let withPropsParam = arguments["ObjectProperties"] as? [String:Any] {
            url = withPropsParam["url"] as? String
        }
        return url
    }
    
    class func accountAndFolderForNewFeed(appleEvent:NSAppleEventDescriptor?) -> (Account, Folder?) {
        var account = AccountManager.shared.localAccount
        var folder:Folder? = nil
        if let appleEvent = appleEvent {
            var descriptorToConsider:NSAppleEventDescriptor?
            if let insertionLocationDescriptor = appleEvent.paramDescriptor(forKeyword:keyAEInsertHere) {
                 print("insertionLocation : \(insertionLocationDescriptor)")
                 // insertion location can be a typeObjectSpecifier, e.g.  'in account "Acct"'
                 // or a typeInsertionLocation, e.g.   'at end of folder "
                 if (insertionLocationDescriptor.descriptorType == "insl".FourCharCode())  {
                     descriptorToConsider = insertionLocationDescriptor.forKeyword("kobj".FourCharCode())
                 } else if ( insertionLocationDescriptor.descriptorType == "obj ".FourCharCode())  {
                     descriptorToConsider = insertionLocationDescriptor
                 }
            } else if let subjectDescriptor = appleEvent.attributeDescriptor(forKeyword:"subj".FourCharCode()) {
                descriptorToConsider = subjectDescriptor
            }
            
            if let descriptorToConsider = descriptorToConsider {
                guard let newContainerSpecifier = NSScriptObjectSpecifier(descriptor:descriptorToConsider) else {return (account, folder)}
                let newContainer = newContainerSpecifier.objectsByEvaluatingSpecifier
                if let scriptableAccount = newContainer as? ScriptableAccount {
                    account = scriptableAccount.account
                } else if let scriptableFolder = newContainer as? ScriptableFolder {
                    if let folderAccount = scriptableFolder.folder.account {
                        folder = scriptableFolder.folder
                        account = folderAccount
                    }
                }
            }
            print("found account : \(account)")
            print("found folder : \(folder)")
        }
        return (account, folder)
    }
    
    class func handleCreateElement(command:NSCreateCommand) -> Any?  {
        let appleEventManager = NSAppleEventManager.shared()
        if let receivers = command.receiversSpecifier  {
            print("receivers : \(receivers)")
        }
        if let evaluatedReceivers = command.evaluatedReceivers  {
            print("evaluatedReceivers : \(evaluatedReceivers)")
        }
        if let evaluatedArguments = command.evaluatedArguments  {
            print("evaluatedArguments : \(evaluatedArguments)")
        }
        if let directObject = command.directParameter  {
            print("directObject : \(directObject)")
        }
        if let appleEvent = command.appleEvent  { // keyDirectObject
            print("appleEvent : \(appleEvent)")
            if let subjectDescriptor = appleEvent.attributeDescriptor(forKeyword:"subj".FourCharCode()) {
                print("subjectDescriptor : \(subjectDescriptor)")
                let subjectObjectSpecifier = NSScriptObjectSpecifier(descriptor:subjectDescriptor)
                let subjects = subjectObjectSpecifier?.objectsByEvaluatingSpecifier
                print("resolvedSubjects : \(subjects)")
            }
        }
        let commandDescription = command.commandDescription
        print("commandDescription : \(commandDescription)")
        
        let (account, folder) = self.accountAndFolderForNewFeed(appleEvent:command.appleEvent)
        let scriptableAccount = ScriptableAccount(account)
        guard let arguments = command.arguments else {return nil}
        guard let newObjectClass = arguments["ObjectClass"] as? Int else {return nil}
        guard (newObjectClass.FourCharCode() == "Feed".FourCharCode()) else {return nil}
        guard let url = self.urlForNewFeed(arguments:arguments) else {return nil}
        
        if let existingFeed = account.existingFeed(withURL:url) {
            return ScriptableFeed(existingFeed, container:scriptableAccount)
        }
    
        // at this point, we have to download the feed and parse it.
        // RS Parser does the callback for the download on the main thread
        // because we can't wait here (on the main thread, maybe) for the callback, we have to return from this function
        // generally, the means handling the appleEvent is over, but to prevent the apple event from returning
        // we call suspendExecution here.  When we get the callback, we can resume execution
        command.suspendExecution()
        
        self.parsedFeedForURL(url, { (parsedFeedOptional) in
            if let parsedFeed = parsedFeedOptional {
                let titleFromFeed = parsedFeed.title
                let titleFromArgs = arguments["name"] as? String
             
                guard let feed = account.createFeed(with: titleFromFeed, editedName: titleFromArgs, url: url) else {
                    command.resumeExecution(withResult:nil)
                    return
                }
                account.update(feed, with:parsedFeed, {})
                
                // add the feed, puttin git in a folder if needed
                if account.addFeed(feed, to: folder) {
                    NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
                }

                let resolvedKeyDictionary = command.resolvedKeyDictionary
                print("resolvedKeyDictionary : \(resolvedKeyDictionary)")
                let scriptableFeed = ScriptableFeed(feed, container:ScriptableAccount(account))
                command.resumeExecution(withResult:scriptableFeed.objectSpecifier)
            } else {
                command.resumeExecution(withResult:nil)
            }
        })
        return nil
    }
 

 

    // MARK: --- Scriptable properties ---
    
    @objc(url)
    var url:String  {
        return self.feed.url
    }
    
    @objc(uniqueId)
    var uniqueId:String  {
        return self.feed.feedID
    }
    
    @objc(name)
    var name:String  {
        return self.feed.name ?? ""
    }

    @objc(homePageURL)
    var homePageURL:String  {
        return self.feed.homePageURL ?? ""
    }

    @objc(iconURL)
    var iconURL:String  {
        return self.feed.iconURL ?? ""
    }

    @objc(faviconURL)
    var faviconURL:String  {
        return self.feed.faviconURL ?? ""
    }

    @objc(opmlRepresentation)
    var opmlRepresentation:String  {
        return self.feed.OPMLString(indentLevel:0)
    }
    
    // MARK: --- scriptable elements ---

    @objc(authors)
    var authors:NSArray {
        let feedAuthors = feed.authors ?? []
        return feedAuthors.map { ScriptableAuthor($0, container:self) } as NSArray
    }
     
    @objc(valueInAuthorsWithUniqueID:)
    func valueInAuthors(withUniqueID id:String) -> ScriptableAuthor? {
        guard let author = feed.authors?.first(where:{$0.authorID == id}) else { return nil }
        return ScriptableAuthor(author, container:self)
    }
    
    @objc(articles)
    var articles:NSArray {
        let feedArticles = feed.fetchArticles()
        // the articles are a set, use the sorting algorithm from the viewer
        let sortedArticles = feedArticles.sorted(by:{
            return $0.logicalDatePublished > $1.logicalDatePublished
        })
        return sortedArticles.map { ScriptableArticle($0, container:self) } as NSArray
    }
    
    @objc(valueInArticlesWithUniqueID:)
    func valueInArticles(withUniqueID id:String) -> ScriptableArticle? {
        let articles = feed.fetchArticles()
        guard let article = articles.first(where:{$0.uniqueID == id}) else { return nil }
        return ScriptableArticle(article, container:self)
    }

}
