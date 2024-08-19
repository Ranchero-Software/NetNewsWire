//
//  ParserData.swift
//
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public struct ParserData: Sendable {

	let url: String
	let data: Data

	public init(url: String, data: Data) {
		self.url = url
		self.data = data
	}
}
