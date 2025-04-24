//
//  HTTPDateInfo.swift
//  RSWeb
//
//  Created by Maurice Parker on 5/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

public struct HTTPDateInfo: Codable, Equatable {
	
	private static let formatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "EEEE, dd LLL yyyy HH:mm:ss zzz"
		return dateFormatter
	}()
	
	public let date: Date?
	
	public init?(urlResponse: HTTPURLResponse) {
		if let headerDate = urlResponse.valueForHTTPHeaderField(HTTPResponseHeader.date) {
			date = HTTPDateInfo.formatter.date(from: headerDate)
		} else {
			date = nil
		}
	}
	
}
