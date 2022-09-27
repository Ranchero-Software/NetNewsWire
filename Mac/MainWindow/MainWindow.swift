//
//  MainWindow.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/26/22.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import Foundation

class MainWindow: NSWindow {
	
	override func sendEvent(_ event: NSEvent) {
		
		// Since the Toolbar intercepts right clicks we need to stop it from doing that here
		// so that the ArticleExtractorButton can receive right click events.
		if event.isRightClick,
		   let frameView = contentView?.superview,
		   let view = frameView.hitTest(frameView.convert(event.locationInWindow, from: nil)),
		   type(of: view).description() == "NSToolbarView" {

			for subview in view.subviews {
				for subsubview in subview.subviews {
					let candidateView = subsubview.hitTest(subsubview.convert(event.locationInWindow, from: nil))
					if candidateView is ArticleExtractorButton {
						candidateView?.rightMouseDown(with: event)
						return
					}
				}
			}
			
		}
		
		super.sendEvent(event)
	}
}
