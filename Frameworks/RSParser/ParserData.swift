//
//  ParserData.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

@objc public final class ParserData: NSObject {

	public let url: String
	public let data: Data

	public init(url: String, data: Data) {

		self.url = url
		self.data = data
		super.init()
	}
}
