//
//  UTType.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 31/05/2023.
//  Copyright © 2023 Ranchero Software. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

public extension UTType {
	static var nnwTheme: UTType {
		UTType("com.ranchero.netnewswire.theme")!
	}
	static var opml: UTType {
		UTType("public.opml")!
	}
}
