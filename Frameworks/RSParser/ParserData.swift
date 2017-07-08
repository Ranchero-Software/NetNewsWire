//
//  ParserData.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

@objc public final class ParserData: NSObject {

	@objc public let url: String
	@objc public let data: Data

	public init(url: String, data: Data) {

		self.url = url
		self.data = data
		super.init()
	}
}
