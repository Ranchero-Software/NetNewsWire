//
//  OPMLDocument.swift
//
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public struct OPMLDocument: Sendable {

	public let title: String
	public let url: String
	public let items: [OPMLItem]?
}
