//
//  OPMLDocument.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 29/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import UniformTypeIdentifiers

public struct OPMLDocument: FileDocument {
	
	public var account: Account!
	
	public static var readableContentTypes: [UTType] {
		UTType.types(tag: "opml", tagClass: .filenameExtension, conformingTo: nil)
	}
	
	public static var writableContentTypes: [UTType] {
		UTType.types(tag: "opml", tagClass: .filenameExtension, conformingTo: nil)
	}
	
	public init(configuration: ReadConfiguration) throws {
		
	}
	
	public init(_ account: Account) throws {
		self.account = account
	}
	
	public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let accountName = account.nameForDisplay.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces)
		let filename = "Subscriptions-\(accountName).opml"
		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		let opmlString = OPMLExporter.OPMLString(with: account, title: filename)
		try opmlString.write(to: tempFile, atomically: true, encoding: String.Encoding.utf8)
		let wrapper = try FileWrapper(url: tempFile)
		return wrapper
	}
}
