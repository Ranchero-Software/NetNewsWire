//
//  OPMLImporter.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/5/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSParser
import Account
import RSCore

struct OPMLImporter {

	static func parseAndImport(fileURL: URL, account: Account) throws {

		var fileData: Data?

		do {
			fileData = try Data(contentsOf: fileURL)
		} catch {
			print("Error reading OPML file. \(error)")
			throw error
		}

		guard let opmlData = fileData else {
			return
		}

		let parserData = ParserData(url: fileURL.absoluteString, data: opmlData)
		var opmlDocument: RSOPMLDocument?

		do {
			opmlDocument = try RSOPMLParser.parseOPML(with: parserData)
		} catch {
			print("Error parsing OPML file. \(error)")
			throw error
		}

		if let opmlDocument = opmlDocument {
			BatchUpdate.shared.perform {
				account.importOPML(opmlDocument)
			}
		}
	}
}
