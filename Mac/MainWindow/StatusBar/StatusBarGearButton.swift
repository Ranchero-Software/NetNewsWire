//
//  StatusBarGearButton.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/12/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit

@MainActor protocol StatusBarGearButtonDelegate: AnyObject {
	func gearButtonMenu(_ gearButton: StatusBarGearButton) -> NSMenu?
}

/// The gear-and-chevron button in the status bar. Clicking it pops up the delegate’s menu.
final class StatusBarGearButton: NSView {

	weak var delegate: StatusBarGearButtonDelegate?

	private static let gearSymbolName = "gearshape.fill"
	private static let chevronSymbolName = "chevron.down"
	private static let gearPointSize: CGFloat = 12
	private static let chevronPointSize: CGFloat = 7
	private static let chevronSpacing: CGFloat = 2.5
	private static let lightGray: CGFloat = 0.4
	private static let darkGray: CGFloat = 0.65

	private static let color = NSColor(name: nil) { appearance in
		let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
		let white = isDark ? darkGray : lightGray
		return NSColor(srgbRed: white, green: white, blue: white, alpha: 1)
	}
	private static let gearImage = symbolImage(gearSymbolName, pointSize: gearPointSize, weight: .regular)
	private static let chevronImage = symbolImage(chevronSymbolName, pointSize: chevronPointSize, weight: .semibold)

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	override var intrinsicContentSize: NSSize {
		let gearWidth = Self.gearImage?.size.width ?? 0
		let chevronWidth = Self.chevronImage?.size.width ?? 0
		return NSSize(width: ceil(gearWidth + Self.chevronSpacing + chevronWidth), height: NSView.noIntrinsicMetric)
	}

	override func draw(_ dirtyRect: NSRect) {
		guard let gearImage = Self.gearImage, let chevronImage = Self.chevronImage else {
			return
		}
		NSGraphicsContext.saveGraphicsState()
		defer {
			NSGraphicsContext.restoreGraphicsState()
		}
		MainWindowStatusBarView.etchedShadow.set()

		let gearRect = NSRect(x: bounds.minX, y: floor(bounds.midY - gearImage.size.height / 2), width: gearImage.size.width, height: gearImage.size.height)
		gearImage.draw(in: gearRect)
		let chevronRect = NSRect(x: gearRect.maxX + Self.chevronSpacing, y: floor(bounds.midY - chevronImage.size.height / 2), width: chevronImage.size.width, height: chevronImage.size.height)
		chevronImage.draw(in: chevronRect)
	}

	override func mouseDown(with event: NSEvent) {
		popUpMenu()
	}

	override func accessibilityPerformPress() -> Bool {
		popUpMenu()
	}
}

private extension StatusBarGearButton {

	func commonInit() {
		let description = NSLocalizedString("Actions", comment: "Status bar gear menu accessibility label")
		setAccessibilityElement(true)
		setAccessibilityRole(.popUpButton)
		setAccessibilityLabel(description)
		toolTip = description
	}

	@discardableResult
	func popUpMenu() -> Bool {
		guard let menu = delegate?.gearButtonMenu(self) else {
			return false
		}
		menu.popUp(positioning: nil, at: NSPoint(x: bounds.minX, y: bounds.minY), in: self)
		return true
	}

	static func symbolImage(_ name: String, pointSize: CGFloat, weight: NSFont.Weight) -> NSImage? {
		let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight).applying(NSImage.SymbolConfiguration(paletteColors: [color]))
		return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
	}
}
