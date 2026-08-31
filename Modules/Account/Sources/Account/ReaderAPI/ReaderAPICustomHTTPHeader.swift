//
//  ReaderAPICustomHTTPHeader.swift
//  Account
//
//  Created by NetNewsWire.
//

import Foundation

nonisolated public struct ReaderAPICustomHTTPHeader: Codable, Equatable, Sendable {

	public let name: String
	public let value: String

	public init?(name: String, value: String) {
		let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
		let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !trimmedName.isEmpty, !trimmedValue.isEmpty, Self.isValidName(trimmedName), !Self.containsNewline(trimmedValue) else {
			return nil
		}

		self.name = trimmedName
		self.value = trimmedValue
	}

	public static func isValidName(_ name: String) -> Bool {
		guard !name.isEmpty else {
			return false
		}

		let allowedScalars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&'*+-.^_`|~")
		return name.unicodeScalars.allSatisfy { allowedScalars.contains($0) }
	}

	private static func containsNewline(_ value: String) -> Bool {
		value.contains("\n") || value.contains("\r")
	}
}
