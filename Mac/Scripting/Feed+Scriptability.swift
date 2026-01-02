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
@MainActor final class ScriptableFeed: NSObject, UniqueIDScriptingObject, @preconcurrency ScriptingObjectContainer {
    let feed: Feed
    nonisolated(unsafe) let container: ScriptingObjectContainer

    init (_ feed: Feed, container: ScriptingObjectContainer) {
        self.feed = feed
        self.container = container
    }

    @objc(objectSpecifier)
    nonisolated override var objectSpecifier: NSScriptObjectSpecifier? {
        let scriptObjectSpecifier = self.container.makeFormUniqueIDScriptObjectSpecifier(forObject:self)
        return scriptObjectSpecifier
    }

    @objc(scriptingSpecifierDescriptor)
    func scriptingSpecifierDescriptor() -> NSScriptObjectSpecifier {
        objectSpecifier ?? NSScriptObjectSpecifier()
    }

    // MARK: --- ScriptingObject protocol ---

    nonisolated var scriptingKey: String {
        "feeds"
    }

    // MARK: --- UniqueIdScriptingObject protocol ---

    // I am not sure if account should prefer to be specified by name or by ID
    // but in either case it seems like the accountID would be used as the keydata, so I chose ID
    @objc(uniqueId)
    nonisolated var scriptingUniqueID: Any {
        feed.feedID
    }

    // MARK: --- ScriptingObjectContainer protocol ---

    nonisolated var scriptingClassDescription: NSScriptClassDescription {
       classDescription as! NSScriptClassDescription
    }

    func deleteElement(_ element:ScriptingObject) {
    }

    // MARK: --- handle NSCreateCommand ---

    class func urlForNewFeed(arguments: [String:Any]) -> String?  {
        var url: String?
        if let withDataParam = arguments["ObjectData"] {
            if let objectDataDescriptor = withDataParam as? NSAppleEventDescriptor {
                url = objectDataDescriptor.stringValue
            }
        } else if let withPropsParam = arguments["ObjectProperties"] as? [String:Any] {
            url = withPropsParam["url"] as? String
        }
        return url
    }

    class func scriptableFeed(_ feed: Feed, account: Account, folder: Folder?) -> ScriptableFeed  {
        let scriptableAccount = ScriptableAccount(account)
        if let folder = folder {
            let scriptableFolder = ScriptableFolder(folder, container: scriptableAccount)
            return ScriptableFeed(feed, container: scriptableFolder)
        } else  {
            return ScriptableFeed(feed, container: scriptableAccount)
        }
    }

    class func scriptableFeed(for feed: Feed) -> ScriptableFeed? {
		guard let account = feed.account else {
			return nil
		}

        // Find the proper container hierarchy
        let containers = account.existingContainers(withFeed: feed)
        var folder: Folder?

        // Check if feed is in a folder
        for container in containers {
            if let foundFolder = container as? Folder {
                folder = foundFolder
                break
            }
        }

        return scriptableFeed(feed, account: account, folder: folder)
    }

    static func handleCreateElement(command: NSCreateCommand) -> Any?  {
		guard command.isCreateCommand(forClass:"Feed") else {
			return nil
		}
		guard let arguments = command.arguments else {
			return nil
		}

        let titleFromArgs = command.property(forKey: "name") as? String
        let (account, folder) = command.accountAndFolderForNewChild()
		guard let url = self.urlForNewFeed(arguments:arguments) else {
			return nil
		}

        if let existingFeed = account.existingFeed(withURL: url) {
            return scriptableFeed(existingFeed, account:account, folder:folder).objectSpecifier
        }

		let container: Container = folder != nil ? folder! : account

        // We need to download the feed and parse it.
        // RSParser does the callback for the download on the main thread.
        // Because we can't wait here (on the main thread) for the callback, we have to return from this function.
        // Generally, returning from an AppleEvent handler function means that handling the Apple event is over,
        // but we don’t yet have the result of the event yet, so we prevent the Apple event from returning by calling
        // suspendExecution(). When we get the callback, we supply the event result and call resumeExecution().
        command.suspendExecution()

		account.createFeed(url: url, name: titleFromArgs, container: container, validateFeed: true) { result in
			switch result {
			case .success(let feed):
				NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
				let scriptableFeed = self.scriptableFeed(feed, account: account, folder: folder)
				command.resumeExecution(withResult: scriptableFeed.objectSpecifier)
			case .failure:
				command.resumeExecution(withResult: nil)
			}

		}

        return nil
    }

    // MARK: --- Scriptable properties ---

    @objc(url)
    var url: String  {
        feed.url
    }

    @objc(name)
    var name: String  {
        feed.name ?? ""
    }

    @objc(homePageURL)
    var homePageURL: String  {
		feed.homePageURL ?? ""
    }

    @objc(iconURL)
    var iconURL: String  {
        feed.iconURL ?? ""
    }

    @objc(faviconURL)
    var faviconURL: String  {
        feed.faviconURL ?? ""
    }

    @objc(opmlRepresentation)
    var opmlRepresentation: String  {
        feed.OPMLString(indentLevel:0)
    }

    // MARK: --- scriptable elements ---

    @objc(authors)
    var authors: NSArray {
        let feedAuthors = feed.authors ?? []
        return feedAuthors.map { ScriptableAuthor($0, container:self) } as NSArray
    }

    @objc(valueInAuthorsWithUniqueID:)
    func valueInAuthors(withUniqueID id: String) -> ScriptableAuthor? {
		guard let author = feed.authors?.first(where: {$0.authorID == id}) else {
			return nil
		}
        return ScriptableAuthor(author, container:self)
    }

    @objc(articles)
    var articles: NSArray {
        let feedArticles = (try? feed.fetchArticles()) ?? Set<Article>()
        // the articles are a set, use the sorting algorithm from the viewer
        let sortedArticles = feedArticles.sorted(by: {
            return $0.logicalDatePublished > $1.logicalDatePublished
        })
        return sortedArticles.map { ScriptableArticle($0, container:self) } as NSArray
    }

    @objc(valueInArticlesWithUniqueID:)
    func valueInArticles(withUniqueID id: String) -> ScriptableArticle? {
        let articles = (try? feed.fetchArticles()) ?? Set<Article>()
		guard let article = articles.first(where: {$0.uniqueID == id}) else {
			return nil
		}
        return ScriptableArticle(article, container: self)
    }
}
