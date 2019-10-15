//
//  NNW3Importer.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

class NNW3PlistConverter {
	
	static var defaultFilePath: String {
		return ("~/Library/Application Support/NetNewsWire/Subscriptions.plist" as NSString).expandingTildeInPath
	}
	
	static func convertToOPML(url: URL) -> URL? {
		guard let data = try? Data(contentsOf: url) else {
			return nil
		}
		
		guard let nnw3plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: AnyObject]] else {
			return nil
		}

		let opmlURL = FileManager.default.temporaryDirectory.appendingPathComponent("NNW3.opml")
		let doc = NNW3Document(plist: nnw3plist)
		let opml = doc.makeXML(indentLevel: 0)
		do {
			try opml.write(to: opmlURL, atomically: true, encoding: .utf8)
		} catch let error as NSError {
			NSApplication.shared.presentError(error)
			return nil
		}

		return opmlURL
	}

}
