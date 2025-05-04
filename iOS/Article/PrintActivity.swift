//
//  PrintActivity.swift
//  NetNewsWire-iOS
//
//  Created by Léo Natan on 4/5/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit
import WebKit

class PrintActivity: UIActivity {
	private let webView: WKWebView?
	
	init(webView: WKWebView?) {
		self.webView = webView
	}
	
	private var activityItems: [Any]?
	
	override var activityTitle: String? {
		return NSLocalizedString("Print", comment: "Print")
	}
	
	override var activityImage: UIImage? {
		return UIImage(systemName: "printer", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
	}
	
	override var activityType: UIActivity.ActivityType? {
		return UIActivity.ActivityType(rawValue: "com.rancharo.NetNewsWire-Evergreen.print")
	}
	
	override class var activityCategory: UIActivity.Category {
		return .action
	}
	
	override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		return webView != nil
	}
	
	override func prepare(withActivityItems activityItems: [Any]) {
		self.activityItems = activityItems
	}
	
	override func perform() {
		guard let webView else {
			return
		}
		
		let printFormatter = webView.viewPrintFormatter()
		printFormatter.perPageContentInsets = UIEdgeInsets(top: 35.0, left: 35.0, bottom: 35.0, right: 35.0)
		
		let printInfo = UIPrintInfo(dictionary: nil)
		printInfo.jobName = "page"
		printInfo.outputType = .general
		
		let printController = UIPrintInteractionController.shared
		printController.printInfo = printInfo
		printController.showsPaperSelectionForLoadedPapers = true
		printController.showsPaperOrientation = true
		printController.printFormatter = printFormatter
		printController.present(animated: true, completionHandler: nil)
	}
	
}
