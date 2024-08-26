//
//  OPMLDocument.swift
//
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

public final class OPMLDocument: OPMLItem {

	public var title: String? = nil
	public var url: String? = nil

	init(url: String?) {
		self.url = url
		super.init(attributes: nil)
	}
}
