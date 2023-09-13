//
//  FeedlyModels.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct FeedlyCategory: Decodable {
    let label: String
    let id: String
}

struct FeedlyCollection: Codable {
	let feeds: [FeedlyFeed]
	let label: String
	let id: String
}

struct FeedlyCollectionParser {
	let collection: FeedlyCollection

	private let rightToLeftTextSantizer = FeedlyRTLTextSanitizer()

	var folderName: String {
		return rightToLeftTextSantizer.sanitize(collection.label) ?? ""
	}

	var externalID: String {
		return collection.id
	}
}

struct FeedlyFeed: Codable {
	let id: String
	let title: String?
	let updated: Date?
	let website: String?
}

struct FeedlyFeedsSearchResponse: Decodable {

	struct Feed: Decodable {
		let title: String
		let feedId: String
	}

	let results: [Feed]
}

struct FeedlyLink: Decodable {
	let href: String

	/// The mime type of the resource located by `href`.
	/// When `nil`, it's probably a web page?
	/// https://groups.google.com/forum/#!searchin/feedly-cloud/feed$20url%7Csort:date/feedly-cloud/Rx3dVd4aTFQ/Hf1ZfLJoCQAJ
	let type: String?
}

struct FeedlyOrigin: Decodable {
	let title: String?
	let streamId: String?
	let htmlUrl: String?
}

struct FeedlyStream: Decodable {
	let id: String

	/// Of the most recent entry for this stream (regardless of continuation, newerThan, etc).
	let updated: Date?

	/// the continuation id to pass to the next stream call, for pagination.
	/// This id guarantees that no entry will be duplicated in a stream (meaning, there is no need to de-duplicate entries returned by this call).
	/// If this value is not returned, it means the end of the stream has been reached.
	let continuation: String?
	let items: [FeedlyEntry]

	var isStreamEnd: Bool {
		return continuation == nil
	}
}

struct FeedlyStreamIDs: Decodable {
	let continuation: String?
	let ids: [String]

	var isStreamEnd: Bool {
		return continuation == nil
	}
}

struct FeedlyTag: Decodable {
	let id: String
	let label: String?
}
