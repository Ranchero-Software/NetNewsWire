//
//  DownloadObject.swift
//  RSWeb
//
//  Created by Brent Simmons on 8/3/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public final class DownloadObject: Hashable {
	
	public let url: URL
	public var data = Data()
	
	public var hashValue: Int {
		return url.hashValue
	}
	
	public init(url: URL) {
		
		self.url = url
	}

	public static func ==(lhs: DownloadObject, rhs: DownloadObject) -> Bool {

		return lhs.url == rhs.url && lhs.data == rhs.data
	}
}

