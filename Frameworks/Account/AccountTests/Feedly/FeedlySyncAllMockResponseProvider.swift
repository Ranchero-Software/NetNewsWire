//
//  FeedlySyncAllMockResponseProvider.swift
//  AccountTests
//
//  Created by Kiel Gillard on 1/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

class FeedlyMockResponseProvider: TestTransportMockResponseProviding {
	
	let subdirectory: String
	
	init(findingMocksIn subdirectory: String) {
		self.subdirectory = subdirectory
	}
	
	func mockResponseFileUrl(for components: URLComponents) -> URL? {
		let bundle = Bundle(for: FeedlyMockResponseProvider.self)
		
		// Match request for collections to build a list of folders.
		if components.path.contains("v3/collections") {
			return bundle.url(forResource: "collections", withExtension: "json", subdirectory: subdirectory)
		}
		
		guard let queryItems = components.queryItems else {
			return nil
		}
		
		// Match requests for starred articles from global.saved.
		if components.path.contains("streams/contents") &&
			queryItems.contains(where: { ($0.value ?? "").contains("global.saved") }) {
			return bundle.url(forResource: "starred", withExtension: "json", subdirectory: subdirectory)
		}
		
		let continuation = queryItems.first(where: { $0.name.contains("continuation") })?.value
		
		// Match requests for unread article ids.
		if components.path.contains("streams/ids") && queryItems.contains(where: { $0.name.contains("unreadOnly") }) {
			
			// if there is a continuation, return the page for it
			if let continuation = continuation, let data = continuation.data(using: .utf8) {
				let base64 = data.base64EncodedString() // at least base64 can be used as a path component.
				return bundle.url(forResource: "unreadIds@\(base64)", withExtension: "json", subdirectory: subdirectory)
				
			} else {
				// return first page
				return bundle.url(forResource: "unreadIds", withExtension: "json", subdirectory: subdirectory)
			}
		}
		
		// Match requests for the contents of global.all.
		if components.path.contains("streams/contents") &&
			queryItems.contains(where: { ($0.value ?? "").contains("global.all") }){
			
			// if there is a continuation, return the page for it
			if let continuation = continuation, let data = continuation.data(using: .utf8) {
				let base64 = data.base64EncodedString() // at least base64 can be used as a path component.
				return bundle.url(forResource: "global.all@\(base64)", withExtension: "json", subdirectory: subdirectory)
				
			} else {
				// return first page
				return bundle.url(forResource: "global.all", withExtension: "json", subdirectory: subdirectory)
			}
		}
		
		return nil
	}
}
