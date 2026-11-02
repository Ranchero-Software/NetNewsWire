//
//  FeedbinArticle.swift
//  Account
//
//  Created by Brent Simmons on 12/11/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSCore

final class FeedbinEntry: Decodable, Sendable {
	let articleID: Int
	let feedID: Int
	let title: String?
	let url: String?
	let authorName: String?
	let contentHTML: String?
	let summary: String?
	let datePublished: String?
	let dateArrived: String?
	let jsonFeed: FeedbinEntryJSONFeed?
	let images: FeedbinEntryImages?
	let enclosure: FeedbinEntryEnclosure?

	// Feedbin dates can't be decoded by the JSONDecoding 8601 decoding strategy. Feedbin
	// requires a very specific date formatter to work and even then it fails occasionally.
	// Rather than loose all the entries we only lose the one date by decoding as a string
	// and letting the one date fail when parsed.
	var parsedDatePublished: Date? {
		if let datePublished {
			return DateParser.date(from: datePublished)
		}
		return nil
	}

	var imageURL: String? {
		images?.originalURL ?? enclosure?.itunesImageURL
	}

	var thumbnailURL: String? {
		images?.thumbnail?.cdnURL
	}

	var attachments: [ParsedAttachment]? {
		guard let attachment = enclosure?.parsedAttachment else {
			return nil
		}
		return [attachment]
	}

	enum CodingKeys: String, CodingKey {
		case articleID = "id"
		case feedID = "feed_id"
		case title = "title"
		case url = "url"
		case authorName = "author"
		case contentHTML = "content"
		case summary = "summary"
		case datePublished = "published"
		case dateArrived = "created_at"
		case jsonFeed = "json_feed"
		case images = "images"
		case enclosure = "enclosure"
	}
}

struct FeedbinEntryJSONFeed: Decodable, Sendable {
	let jsonFeedAuthor: FeedbinEntryJSONFeedAuthor?
	let jsonFeedExternalURL: String?

	enum CodingKeys: String, CodingKey {
		case jsonFeedAuthor = "author"
		case jsonFeedExternalURL = "external_url"
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		do {
			jsonFeedAuthor = try container.decode(FeedbinEntryJSONFeedAuthor.self, forKey: .jsonFeedAuthor)
		} catch {
			jsonFeedAuthor = nil
		}
		do {
			jsonFeedExternalURL = try container.decode(String.self, forKey: .jsonFeedExternalURL)
		} catch {
			jsonFeedExternalURL = nil
		}
	}
}

struct FeedbinEntryJSONFeedAuthor: Decodable, Sendable {
	let url: String?
	let avatarURL: String?

	enum CodingKeys: String, CodingKey {
		case url = "url"
		case avatarURL = "avatar"
	}
}

struct FeedbinEntryImages: Decodable, Sendable {
	let originalURL: String?
	let thumbnail: FeedbinEntryThumbnail?

	enum CodingKeys: String, CodingKey {
		case originalURL = "original_url"
		case thumbnail = "size_1"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		originalURL = try? container.decodeIfPresent(String.self, forKey: .originalURL)
		thumbnail = try? container.decodeIfPresent(FeedbinEntryThumbnail.self, forKey: .thumbnail)
	}
}

/// Feedbin’s resized copy of the image, on its CDN.
struct FeedbinEntryThumbnail: Decodable, Sendable {
	let cdnURL: String?

	enum CodingKeys: String, CodingKey {
		case cdnURL = "cdn_url"
	}
}

struct FeedbinEntryEnclosure: Decodable, Sendable {
	let url: String?
	let mimeType: String?
	let length: String?
	let itunesDuration: String?
	let itunesImageURL: String?

	var parsedAttachment: ParsedAttachment? {
		guard let url else {
			return nil
		}
		let durationInSeconds = ParsedAttachment.durationInSeconds(itunesDuration)
		return ParsedAttachment(url: url, mimeType: mimeType, title: nil, sizeInBytes: sizeInBytes, durationInSeconds: durationInSeconds, width: nil, height: nil, medium: nil)
	}

	private var sizeInBytes: Int? {
		guard let length, let sizeInBytes = Int(length), sizeInBytes > 0 else {
			return nil
		}
		return sizeInBytes
	}

	enum CodingKeys: String, CodingKey {
		case url = "enclosure_url"
		case mimeType = "enclosure_type"
		case length = "enclosure_length"
		case itunesDuration = "itunes_duration"
		case itunesImageURL = "itunes_image"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		url = try? container.decodeIfPresent(String.self, forKey: .url)
		mimeType = try? container.decodeIfPresent(String.self, forKey: .mimeType)
		length = try? container.decodeIfPresent(String.self, forKey: .length)
		itunesDuration = try? container.decodeIfPresent(String.self, forKey: .itunesDuration)
		itunesImageURL = try? container.decodeIfPresent(String.self, forKey: .itunesImageURL)
	}
}
