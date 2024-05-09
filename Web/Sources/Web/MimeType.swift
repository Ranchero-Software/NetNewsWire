//
//  MimeType.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct MimeType {
	
	// This could certainly use expansion.
	
	public static let png = "image/png"
	public static let jpeg = "image/jpeg"
	public static let jpg = "image/jpg"
	public static let gif = "image/gif"
	public static let tiff = "image/tiff"

	public static let formURLEncoded = "application/x-www-form-urlencoded"
}

public extension String {
	
	func isMimeTypeImage() -> Bool {
		
		return self.isOfGeneralMimeType("image")
	}
	
	func isMimeTypeAudio() -> Bool {
		
		return self.isOfGeneralMimeType("audio")
	}
	
	func isMimeTypeVideo() -> Bool {
		
		return self.isOfGeneralMimeType("video")
	}
	
	func isMimeTypeTimeBasedMedia() -> Bool {
		
		return self.isMimeTypeAudio() || self.isMimeTypeVideo()
	}
	
	private func isOfGeneralMimeType(_ type: String) -> Bool {
		
		let lower = self.lowercased()
		if lower.hasPrefix(type) {
			return true
		}
		if lower.hasPrefix("x-\(type)") {
			return true
		}
		return false
	}
}
