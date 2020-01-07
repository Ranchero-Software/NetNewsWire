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
			
			if Date() > accountLastArticleFetchEndTime.addingTimeInterval(60) {
				
				let relativeDateTimeFormatter = RelativeDateTimeFormatter()
				relativeDateTimeFormatter.dateTimeStyle = .named
				let refreshed = relativeDateTimeFormatter.localizedString(for: accountLastArticleFetchEndTime, relativeTo: Date())
				let localizedRefreshText = NSLocalizedString("Updated %@", comment: "Updated")
				let refreshText = NSString.localizedStringWithFormat(localizedRefreshText as NSString, refreshed) as String
				label.text = refreshText
				
			} else {
				label.text = NSLocalizedString("Updated Just Now", comment: "Updated Just Now")
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
			progressView.setProgress(1, animated: true)
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				self.updateRefreshLabel()
				self.label.isHidden = false
				self.progressView.isHidden = true
				self.progressWidth.isActive = false
				self.progressView.setProgress(0, animated: true)
			}
		} else {
			label.isHidden = true
			progressView.isHidden = false
			self.progressWidth.isActive = true
			self.progressView.setNeedsLayout()
			self.progressView.layoutIfNeeded()
			let percent = Float(progress.numberCompleted) / Float(progress.numberOfTasks)
			
			// Don't let the progress bar go backwards unless we need to go back more than 25%
			if percent > progressView.progress || progressView.progress - percent > 0.25 {
				progressView.setProgress(percent, animated: true)
			}
		}
	}
}
