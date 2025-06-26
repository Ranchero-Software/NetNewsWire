//
//  AboutWindowController.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 26/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Cocoa

class AboutWindowController: NSWindowController {
	
	@IBOutlet weak var appIconImageView: NSImageView!
	@IBOutlet weak var appTitleLabel: NSTextField!
	@IBOutlet weak var versionLabel: NSTextField!
	@IBOutlet weak var copyrightLabel: NSTextField!
	@IBOutlet weak var websiteLabel: LinkLabel!
	@IBOutlet weak var creditsTextView: NSTextView!

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
			let visualEffectView = NSVisualEffectView(frame: contentView.bounds)
			visualEffectView.autoresizingMask = [.width, .height]
			visualEffectView.blendingMode = .behindWindow
			visualEffectView.material = .titlebar
			visualEffectView.state = .active
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
		let copyright = Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "Copyright © 2002-2025 Brent Simmons. All rights reserved."
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
		let centeredParagraphStyle = NSMutableParagraphStyle()
		centeredParagraphStyle.alignment = .center
		creditsTextView.textStorage?.addAttribute(.paragraphStyle, value: centeredParagraphStyle, range: fullRange)
		
		// URL
		let url = URL(string: "https://inessential.com")!
		let attributedString = NSMutableAttributedString(string: "inessential.com")
		attributedString.addAttribute(.link, value: url, range: NSRange(location: 0, length: attributedString.length))
		attributedString.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: NSRange(location: 0, length: attributedString.length))
		attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attributedString.length))
		websiteLabel.attributedStringValue = attributedString
	}
    
}
