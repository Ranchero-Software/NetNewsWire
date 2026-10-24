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

	public static func attachmentsWithJSON(_ data: Data) -> [Attachment]? {
		let decoder = JSONDecoder()
		do {
			return try decoder.decode([Attachment].self, from: data)
		} catch {
			assertionFailure("JSON representation of Attachment array could not be decoded, error: \(error)")
		}
		return nil
	}
}

// MARK: - Display

extension Attachment {

	private static let audioFileExtensions: Set = ["mp3", "m4a", "aac", "wav", "ogg", "oga", "opus", "flac"]
	private static let videoFileExtensions: Set = ["mp4", "m4v", "mov", "webm"]
	private static let imageFileExtensions: Set = ["jpg", "jpeg", "png", "gif", "webp", "heic", "avif"]

	/// How the article view shows this attachment: `.audio`, `.video`, or `.image`.
	/// Nil for anything else. Checks the MIME type, then `medium`, then the URL’s file extension.
	public var displayMedium: Medium? {
		if let mimeType = mimeType?.lowercased() {
			if mimeType.hasPrefix("audio/") {
				return .audio
			}
			if mimeType.hasPrefix("video/") {
				return .video
			}
			if mimeType.hasPrefix("image/") {
				return .image
			}
		}

		if medium == .audio || medium == .video || medium == .image {
			return medium
		}

		guard let pathExtension = URL(string: url)?.pathExtension.lowercased(), !pathExtension.isEmpty else {
			return nil
		}
		if Self.audioFileExtensions.contains(pathExtension) {
			return .audio
		}
		if Self.videoFileExtensions.contains(pathExtension) {
			return .video
		}
		if Self.imageFileExtensions.contains(pathExtension) {
			return .image
		}
		return nil
	}
}

extension Array where Element == Attachment {

	public func json() -> String? {
		let encoder = JSONEncoder()
		do {
			let jsonData = try encoder.encode(self)
			return String(data: jsonData, encoding: .utf8)
		} catch {
			assertionFailure("JSON representation of Attachment array could not be encoded: \(self) error: \(error)")
		}
		return nil
	}
}
