//
//  OPMLDocument.swift
//  RSParser
//
//  Created by Brent Simmons on 4/20/26.
//

// The root of an OPML document — acts as an OPMLItem but also carries the
// document-level `title` (from <title> in <head>) and the URL it was loaded from.

public final class OPMLDocument: OPMLItem {

	public var title: String?
	public var url: String?

	public init(url: String?) {
		super.init()
		self.url = url
	}
}
