//
//  HTTPLinkPagingInfo.swift
//  RSWeb
//
//  Created by Maurice Parker on 5/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

public struct HTTPLinkPagingInfo {
	
	public let nextPage: String?
	public let lastPage: String?
	
	public init(nextPage: String?, lastPage: String?) {
		self.nextPage = nextPage
		self.lastPage = lastPage
	}

	public init(urlResponse: HTTPURLResponse) {
		
		guard let linkHeader = urlResponse.valueForHTTPHeaderField(HTTPResponseHeader.link) else {
			self.init(nextPage: nil, lastPage: nil)
			return
		}

		let links = linkHeader.components(separatedBy: ",")
		
		var dict: [String: String] = [:]
		for link in links {
			let components = link.components(separatedBy:"; ")
			let page = components[0].trimmingCharacters(in: CharacterSet(charactersIn: " <>"))
			dict[components[1]] = page
		}
		
		self.init(nextPage: dict["rel=\"next\""], lastPage: dict["rel=\"last\""])
	}
}
