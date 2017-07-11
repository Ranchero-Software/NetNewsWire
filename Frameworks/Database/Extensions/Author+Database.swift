//
//  Author+Database.swift
//  Database
//
//  Created by Brent Simmons on 7/8/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

extension Author {

	private static let 
	convenience init?(databaseDictionary d: [String: Any]) {

		guard let url = d[DatabaseKey.url] as? String else {
			return nil
		}
		let mimeType = d[DatabaseKey.mimeType] as? String
		let title = d[DatabaseKey.title] as? String
		let durationInSeconds = d[DatabaseKey.durationInSeconds] as? Int

		self.init(url: url, mimeType: mimeType, title: title, durationInSeconds: durationInSeconds)

		

		self.init(name: name, url: url, avatarURL: avatarURL, emailAddress: emailAddress)
	}

	class func attachments(with plist: [Any]) -> [Attachment]? {

		return plist.flatMap{ (oneDictionary) -> Attachment? in
			if let d = oneDictionary as? [String: Any] {
				return Attachment(databaseDictionary: d)
			}
			return nil
		}
	}
}
