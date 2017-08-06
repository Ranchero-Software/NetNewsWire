//
//  Keys.swift
//  Database
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

public struct DatabaseTableName {
	
	static let articles = "articles"
	static let authors = "authors"
	static let authorsLookup = "authorLookup"
	static let statuses = "statuses"
	static let tags = "tags"
	static let attachments = "attachments"
}

public struct DatabaseKey {
	
	// Shared
	static let databaseID = "databaseID"
	static let articleID = "articleID"
	static let accountInfo = "accountInfo"
	static let url = "url"
	static let title = "title"
	
	// Article
	static let feedID = "feedID"
	static let uniqueID = "uniqueID"
	static let contentHTML = "contentHTML"
	static let contentText = "contentText"
	static let externalURL = "externalURL"
	static let summary = "summary"
	static let imageURL = "imageURL"
	static let bannerImageURL = "bannerImageURL"
	static let datePublished = "datePublished"
	static let dateModified = "dateModified"
	static let authors = "authors"
	static let tags = "tags"
	static let attachments = "attachments"
	
	// ArticleStatus
	static let read = "read"
	static let starred = "starred"
	static let userDeleted = "userDeleted"
	static let dateArrived = "dateArrived"

	// Attachment
	static let mimeType = "mimeType"
	static let sizeInBytes = "sizeInBytes"
	static let durationInSeconds = "durationInSeconds"

	// Tag
	static let tagName = "tagName"
	
	// Author
	static let authorID = "authorID"
	static let name = "name"
	static let avatarURL = "avatarURL"
	static let emailAddress = "emailAddress"
}

