//
//  SidebarTableRowView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 8/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit

class SidebarTableRowView : NSTableRowView {

	override var isSelected: Bool {
		didSet {
			cellView?.isSelected = isSelected
		}
	}
	
	init() {
		super.init(frame: NSRect.zero)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	private var cellView: SidebarCell? {
		for oneSubview in subviews {
			if let foundView = oneSubview as? SidebarCell {
				return foundView
			}
		}
		return nil
	}

}
