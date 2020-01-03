//
//  RefeshProgressView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class RefreshProgressView: UIView {
	
	@IBOutlet weak var progressView: UIProgressView!
	@IBOutlet weak var label: UILabel!
	private lazy var progressWidth = progressView.widthAnchor.constraint(equalToConstant: 100.0)
	private var lastLabelDisplayedTime: Date? = nil
	
	override func awakeFromNib() {
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)
		
		if !AccountManager.shared.combinedRefreshProgress.isComplete {
			progressChanged()
		} else {
			updateRefreshLabel()
		}
	}

	func updateRefreshLabel() {
		if let accountLastArticleFetchEndTime = AccountManager.shared.lastArticleFetchEndTime {
			
			if let lastLabelDisplayedTime = lastLabelDisplayedTime, lastLabelDisplayedTime.addingTimeInterval(2) > Date()  {
				return
			}

			lastLabelDisplayedTime = Date()

			if Date() > accountLastArticleFetchEndTime.addingTimeInterval(1) {
				
				let relativeDateTimeFormatter = RelativeDateTimeFormatter()
				relativeDateTimeFormatter.dateTimeStyle = .named
				let refreshed = relativeDateTimeFormatter.localizedString(for: accountLastArticleFetchEndTime, relativeTo: Date())
				let localizedRefreshText = NSLocalizedString("Updated %@", comment: "Updated")
				let refreshText = NSString.localizedStringWithFormat(localizedRefreshText as NSString, refreshed) as String
				label.text = refreshText
				
			} else {
				label.text = NSLocalizedString("Updated just now", comment: "Updated Just Now")
			}
			
		} else {
			label.text = ""
		}

	}
	
	@objc func progressDidChange(_ note: Notification) {
		progressChanged()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
}

// MARK: Private

private extension RefreshProgressView {

	func progressChanged() {
		let progress = AccountManager.shared.combinedRefreshProgress
		
		if progress.isComplete {
			progressView.progress = 1
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				self.updateRefreshLabel()
				self.label.isHidden = false
				self.progressView.isHidden = true
				self.progressWidth.isActive = false
			}
		} else {
			lastLabelDisplayedTime = nil
			label.isHidden = true
			progressView.isHidden = false
			self.progressWidth.isActive = true
			let percent = Float(progress.numberCompleted) / Float(progress.numberOfTasks)
			progressView.progress = percent
		}
	}
}
