//
//  Image-Extensions.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/1/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import RSCore

extension Image {
	
	init(rsImage: RSImage) {
		#if os(macOS)
		self = Image(nsImage: rsImage)
		#endif
		#if os(iOS)
		self = Image(uiImage: rsImage)
		#endif
	}
	
}
