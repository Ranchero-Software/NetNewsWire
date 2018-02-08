//
//  Feed+Scriptability.swift
//  Evergreen
//
//  Created by Olof Hellman on 1/10/18.
//  Copyright © 2018 Olof Hellman. All rights reserved.
//

import Foundation
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
