//
//  AboutWindowController.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 26/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Cocoa

class AboutWindowController: NSWindowController {

	@IBOutlet var appIconImageView: NSImageView!
	@IBOutlet var appTitleLabel: NSTextField!
	@IBOutlet var versionLabel: NSTextField!
	@IBOutlet var copyrightLabel: NSTextField!
	@IBOutlet var websiteLabel: LinkLabel!
	@IBOutlet var creditsTextView: NSTextView!

    override func windowDidLoad() {
        super.windowDidLoad()
		configureWindow()
		updateUI()
    }

	func configureWindow() {
		window?.isOpaque = false
		window?.backgroundColor = .clear
		window?.titlebarAppearsTransparent = true
		window?.titleVisibility = .hidden
		window?.styleMask.insert(.fullSizeContentView)
		if let contentView = window?.contentView {
			let visualEffectView = NSGlassEffectView(frame: contentView.bounds)
			visualEffectView.tintColor = .clear
			visualEffectView.autoresizingMask = [.width, .height]
			contentView.addSubview(visualEffectView, positioned: .below, relativeTo: nil)
		}
	}

	private func updateUI() {

		// App Icon
		appIconImageView.image = NSApp.applicationIconImage

		// Version
		let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
		let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
		let versionString = "Version \(version) (Build \(build))"
		versionLabel.stringValue = versionString

		// Copyright
		let copyright = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "Copyright © 2002-2026 Brent Simmons. All rights reserved."
		copyrightLabel.stringValue = copyright

		// Credits
		if let creditsURL = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
		   let creditsData = try? Data(contentsOf: creditsURL),
		   let attributedString = try? NSAttributedString(data: creditsData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
			creditsTextView.textStorage?.setAttributedString(attributedString)
		} else {
			creditsTextView.string = "Credits not available."
		}

		let fullRange = NSRange(location: 0, length: creditsTextView.string.utf16.count)
		let leadingParagraphStyle = NSMutableParagraphStyle()
		leadingParagraphStyle.alignment = .left
		creditsTextView.textStorage?.addAttribute(.paragraphStyle, value: leadingParagraphStyle, range: fullRange)

		// URL
		let url = URL(string: "https://netnewswire.com/")!
		let attributedString = NSMutableAttributedString(string: "netnewswire.com")
		attributedString.addAttribute(.link, value: url, range: NSRange(location: 0, length: attributedString.length))
		attributedString.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: NSRange(location: 0, length: attributedString.length))
		attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attributedString.length))
		websiteLabel.attributedStringValue = attributedString
	}

}
