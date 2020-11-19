//
//  WidgetDeepLinks.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

enum WidgetDeepLink {
	
	case unread
	case unreadArticle(id: String)
	case today
	case todayArticle(id: String)
	case starred
	case starredArticle(id: String)
	case icon
	
	var url: URL {
		switch self {
		case .unread:
			return URL(string: "nnw://showunread")!
		case .unreadArticle(let articleID):
			var url = URLComponents(url: WidgetDeepLink.unread.url, resolvingAgainstBaseURL: false)!
			url.queryItems = [URLQueryItem(name: "id", value: articleID)]
			return url.url!
		case .today:
			return URL(string: "nnw://showtoday")!
		case .todayArticle(let articleID):
			var url = URLComponents(url: WidgetDeepLink.today.url, resolvingAgainstBaseURL: false)!
			url.queryItems = [URLQueryItem(name: "id", value: articleID)]
			return url.url!
		case .starred:
			return URL(string: "nnw://showstarred")!
		case .starredArticle(let articleID):
			var url = URLComponents(url: WidgetDeepLink.starred.url, resolvingAgainstBaseURL: false)!
			url.queryItems = [URLQueryItem(name: "id", value: articleID)]
			return url.url!
		case .icon:
			return URL(string: "nnw://icon")!
		}
	}
	
}
