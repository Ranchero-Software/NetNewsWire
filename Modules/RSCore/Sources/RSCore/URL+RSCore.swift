//
//  URL-Extensions.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 03/05/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

public extension URL {
	/// Percent encoded `mailto` URL for use with `canOpenUrl`. If the URL doesn't contain the `mailto` scheme, this is `nil`.
	var percentEncodedEmailAddress: URL? {
		guard scheme == "mailto" else {
			return nil
		}
		guard let urlString = absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
			return nil
		}
		return URL(string: urlString)
	}

	/// Percent-encode spaces in links that may contain spaces but are otherwise already percent-encoded.
	///
	/// For performance reasons, try this only if initial URL init fails.
	static func encodeSpacesIfNeeded(_ link: String?) -> URL? {
		guard let link, !link.isEmpty else {
			return nil
		}
		return URL(string: link.replacingOccurrences(of: " ", with: "%20"))
	}
}
