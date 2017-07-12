//
//  Attachment+Database.swift
//  Database
//
//  Created by Brent Simmons on 7/4/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Data

extension Attachment {
	
	init?(databaseDictionary d: [String: Any]) {
		
		guard let url = d[DatabaseKey.url] as? String else {
			return nil
		}
		let mimeType = d[DatabaseKey.mimeType] as? String
		let title = d[DatabaseKey.title] as? String
		let sizeInBytes = d[DatabaseKey.sizeInBytes] as? Int
		let durationInSeconds = d[DatabaseKey.durationInSeconds] as? Int
		
		self.init(url: url, mimeType: mimeType, title: title, sizeInBytes: sizeInBytes, durationInSeconds: durationInSeconds)
	}
	
	static func attachments(with plist: [Any]) -> [Attachment]? {
		
		return plist.flatMap{ (oneDictionary) -> Attachment? in
			if let d = oneDictionary as? [String: Any] {
				return Attachment(databaseDictionary: d)
			}
			return nil
		}
	}
}
