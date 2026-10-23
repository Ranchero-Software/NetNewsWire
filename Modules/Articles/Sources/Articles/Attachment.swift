//
//  Attachment.swift
//  Articles
//
//  Created by Brent Simmons on 10/23/26.
//

import Foundation

/// An enclosure or Media RSS item: audio, video, image, or other file attached to an article.
public struct Attachment: Codable, Hashable, Sendable {

	/// Raw values are stored in the database, so don’t remove or rename cases.
	public enum Medium: String, Codable, Sendable {
		case image
		case audio
		case video
		case document
		case executable
	}

	public let url: String
	public let mimeType: String?
	public let title: String?
	public let sizeInBytes: Int?
	public let durationInSeconds: Int?
	public let width: Int?
	public let height: Int?
	public let medium: Medium?

	public init?(url: String, mimeType: String?, title: String?, sizeInBytes: Int?, durationInSeconds: Int?, width: Int?, height: Int?, medium: Medium?) {
		if url.isEmpty {
			return nil
		}

		self.url = url
		self.mimeType = mimeType
		self.title = title
		self.sizeInBytes = sizeInBytes
		self.durationInSeconds = durationInSeconds
		self.width = width
		self.height = height
		self.medium = medium
	}

	public static func attachmentsWithJSON(_ data: Data) -> Set<Attachment>? {
		let decoder = JSONDecoder()
		do {
			let attachments = try decoder.decode([Attachment].self, from: data)
			return Set(attachments)
		} catch {
			assertionFailure("JSON representation of Attachment array could not be decoded, error: \(error)")
		}
		return nil
	}
}

extension Set where Element == Attachment {

	public func json() -> String? {
		let encoder = JSONEncoder()
		do {
			let jsonData = try encoder.encode(Array(self))
			return String(data: jsonData, encoding: .utf8)
		} catch {
			assertionFailure("JSON representation of Attachment array could not be encoded: \(self) error: \(error)")
		}
		return nil
	}
}
