//
//  AboutWindowController.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 26/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Cocoa

final class AboutWindowController: NSWindowController {
	@IBOutlet var appIconImageView: NSImageView!
	@IBOutlet var appTitleLabel: NSTextField!
	@IBOutlet var versionLabel: NSTextField!
	@IBOutlet var copyrightLabel: LinksTextView!
	@IBOutlet var websiteLabel: LinkLabel!
	@IBOutlet var creditsTextView: LinksTextView!

	override func windowDidLoad() {
		super.windowDidLoad()
		configureWindow()
		updateUI()
	}
}

private extension AboutWindowController {
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

	func updateUI() {
		// App Icon
		appIconImageView.image = NSApp.applicationIconImage

		// Version
		let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
		let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
		let versionString = "Version \(version) (Build \(build))"
		versionLabel.stringValue = versionString

		// Copyright
		let copyrightText = Bundle.main.infoDictionary!["NSHumanReadableCopyright"] as! String
		let copyrightAttributedString = NSMutableAttributedString(string: copyrightText)
		let copyrightFullRange = NSRange(location: 0, length: copyrightAttributedString.length)

		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = .center
		copyrightAttributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: copyrightFullRange)
		copyrightAttributedString.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: copyrightFullRange)
		copyrightAttributedString.addAttribute(.font, value: NSFont.preferredFont(forTextStyle: .subheadline), range: copyrightFullRange)

		if let nameRange = copyrightText.range(of: "Brent Simmons") {
			let nsRange = NSRange(nameRange, in: copyrightText)
			let url = URL(string: "https://inessential.com/")!
			copyrightAttributedString.addAttribute(.link, value: url, range: nsRange)
		}

		copyrightLabel.textStorage?.setAttributedString(copyrightAttributedString)

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
