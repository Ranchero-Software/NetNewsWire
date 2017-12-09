//
//  APIResultParser.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/9/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

public protocol APIResultParser {

	func parsedObject(with: APIResult) -> Any?
}
