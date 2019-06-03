//
//  Feed+Scriptability.swift
//  NetNewsWire
//
//  Created by Olof Hellman on 1/10/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import Foundation
import RSParser
import Account
import Articles

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
    @objc(uniqueId)
    var scriptingUniqueId:Any {
        return feed.feedID
    }

    // MARK: --- ScriptingObjectContainer protocol ---
    
    var scriptingClassDescription: NSScriptClassDescription {
        return self.classDescription as! NSScriptClassDescription
    }
    
    func deleteElement(_ element:ScriptingObject) {
    }

    // MARK: --- handle NSCreateCommand ---

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
    
    class func scriptableFeed(_ feed:Feed, account:Account, folder:Folder?) -> ScriptableFeed  {
        let scriptableAccount = ScriptableAccount(account)
        if let folder = folder {
            let scriptableFolder = ScriptableFolder(folder, container:scriptableAccount)
            return ScriptableFeed(feed, container:scriptableFolder)
        } else  {
            return ScriptableFeed(feed, container:scriptableAccount)
        }
    }
    
    class func handleCreateElement(command:NSCreateCommand) -> Any?  {
        guard command.isCreateCommand(forClass:"Feed") else { return nil }
        guard let arguments = command.arguments else {return nil}
        let titleFromArgs = command.property(forKey:"name") as? String
        let (account, folder) = command.accountAndFolderForNewChild()
        guard let url = self.urlForNewFeed(arguments:arguments) else {return nil}
        
        if let existingFeed = account.existingFeed(withURL:url) {
            return self.scriptableFeed(existingFeed, account:account, folder:folder)
        }
		
		let container: Container = folder != nil ? folder! : account
		
        // at this point, we need to download the feed and parse it.
        // RS Parser does the callback for the download on the main thread (which it probably shouldn't?)
        // because we can't wait here (on the main thread, maybe) for the callback, we have to return from this function
        // Generally, returning from an AppleEvent handler function means that handling the appleEvent is over,
        // but we don't yet have the result of the event yet, so we prevent the AppleEvent from returning by calling
        // suspendExecution().  When we get the callback, we can supply the event result and call resumeExecution()
        command.suspendExecution()
        
		account.createFeed(url: url, name: titleFromArgs, container: container) { result in
			switch result {
			case .success(let feed):
				NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
				let scriptableFeed = self.scriptableFeed(feed, account:account, folder:folder)
				command.resumeExecution(withResult:scriptableFeed.objectSpecifier)
			case .failure:
				command.resumeExecution(withResult:nil)
			}

		}
		
        return nil
    }

    // MARK: --- Scriptable properties ---

    @objc(url)
    var url:String  {
        return self.feed.url
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
