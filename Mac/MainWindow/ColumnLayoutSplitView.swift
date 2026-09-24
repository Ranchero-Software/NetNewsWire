//
//  ColumnLayoutSplitView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/19/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit

/// The split between the timeline and the article view in column layout.
/// On macOS 26 it extends under the sidebar, so the divider is drawn in the visible part only — otherwise the dimple is off-center.
final class ColumnLayoutSplitView: NSSplitView {

	override func drawDivider(in rect: NSRect) {
		super.drawDivider(in: rect.intersection(safeAreaRect))
	}
}
