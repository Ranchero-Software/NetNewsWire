//
//  RSDarkModeAdaptingToolbarButton.swift
//  RSCore
//
//  Created by Daniel Jalkut on 8/28/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

final class RSDarkModeAdaptingToolbarButton: NSButton {
	// Clients probably should not bother using this class unless they want
	// to force the template in dark mode, but if you are using this in a more
	// general context where you want to control and/or override it on a
	// case-by-case basis, set this to false to avoid the templating behavior.
	public var forceTemplateInDarkMode: Bool = true
	var originalImageTemplateState: Bool = false

	public convenience init(image: NSImage, target: Any?, action: Selector?, forceTemplateInDarkMode: Bool = false) {
		self.init(image: image, target: target, action: action)
		self.forceTemplateInDarkMode = forceTemplateInDarkMode
	}

	override func layout() {
		// Always re-set the NSImage template state based on the current dark mode setting
		if #available(macOS 10.14, *) {
			if self.forceTemplateInDarkMode, let targetImage = self.image {
				var newTemplateState: Bool = self.originalImageTemplateState

				if self.effectiveAppearance.isDarkMode {
					newTemplateState = true
				}

				targetImage.isTemplate = newTemplateState
			}
		}

		super.layout()
	}
}
#endif
