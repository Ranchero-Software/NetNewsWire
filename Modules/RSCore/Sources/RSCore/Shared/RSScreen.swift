//
//  RSScreen.swift
//  RSCore
//
//  Created by Maurice Parker on 4/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

#if os(macOS)
import AppKit

public final class RSScreen {

	nonisolated public static var maxScreenScale: CGFloat {
		NSScreen.screens.map(\.backingScaleFactor).max() ?? 2.0
	}
}

#endif

#if os(iOS)
import UIKit

public final class RSScreen {
	nonisolated public static let maxScreenScale = CGFloat(3)
}

#endif
