//
//  Keys.swift
//  Database
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

// MARK: - Database structure

struct DatabaseTableName {
	
	static let articles = "articles"
	static let authors = "authors"
	static let authorsLookup = "authorsLookup"
	static let statuses = "statuses"
	static let attachments = "attachments"
	static let attachmentsLookup = "attachmentsLookup"
}

struct DatabaseKey {
	
	// Shared
	static let articleID = "articleID"
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
	static let attachments = "attachments"
	
	// ArticleStatus
	static let read = "read"
	static let starred = "starred"
	static let userDeleted = "userDeleted"
	static let dateArrived = "dateArrived"

	// Attachment
	static let attachmentID = "attachmentID"
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

struct RelationshipName {
	
	static let authors = "authors"
	static let attachments = "attachments"
}
