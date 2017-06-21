//
//  ParserData.swift
//  RSParser
//
//  Created by Brent Simmons on 6/20/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public final class ParserData {

	let url: String
	let data: Data

	public init(url: String, data: Data) {

		self.url = url
		self.data = data
	}
}
