//
//  AuthorAvatarDownloader.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa
import Data

final class AuthorAvatarDownloader {

	private let imageDownloader: ImageDownloader

	init(imageDownloader: ImageDownloader) {

		self.imageDownloader = imageDownloader
	}

	func image(for author: Author) -> NSImage? {

		guard let avatarURL = author.avatarURL else {
			return nil
		}
		return imageDownloader.image(for: avatarURL)
	}
}
