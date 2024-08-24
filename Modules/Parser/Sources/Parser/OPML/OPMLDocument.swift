//
//  OPMLDocument.swift
//
//
//  Created by Brent Simmons on 8/18/24.
//

import Foundation

final class OPMLDocument: OPMLItem {

	var title: String? = nil
	var url: String? = nil

	init(url: String?) {
		self.url = url
		super.init(attributes: nil)
	}
}
