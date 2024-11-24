//
//  URLComponents.swift
//  
//
//  Created by Maurice Parker on 11/8/20.
//

import Foundation

public extension URLComponents {
	
    	// `+` is a valid character in query component as per RFC 3986 (https://developer.apple.com/documentation/foundation/nsurlcomponents/1407752-queryitems)
 	// workaround:
 	// - http://www.openradar.me/24076063
 	// - https://stackoverflow.com/a/37314144
	var enhancedPercentEncodedQuery: String? {
		guard !(queryItems?.isEmpty ?? true) else {
			return nil
		}
		
		var allowedCharacters = CharacterSet.urlQueryAllowed
		allowedCharacters.remove(charactersIn: "!*'();:@&=+$,/?%#[]")
		
		var queries = [String]()
		for queryItem in queryItems! {
			if let value = queryItem.value?.addingPercentEncoding(withAllowedCharacters: allowedCharacters)?.replacingOccurrences(of: "%20", with: "+") {
				queries.append("\(queryItem.name)=\(value)")
			}
		}
		
		return queries.joined(separator: "&")
	}
	
}
