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
	private lazy var progressWidthConstraint = progressView.widthAnchor.constraint(equalToConstant: 100.0)
	
	override func awakeFromNib() {
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)

		if !AccountManager.shared.combinedRefreshProgress.isComplete {
			progressChanged()
		} else {
			updateRefreshLabel()
		}
		
		scheduleUpdateRefreshLabel()
	}

	override func didMoveToSuperview() {
		progressChanged()
	}

	func updateRefreshLabel() {
		if let accountLastArticleFetchEndTime = AccountManager.shared.lastArticleFetchEndTime {
			
			if Date() > accountLastArticleFetchEndTime.addingTimeInterval(60) {
				
				let relativeDateTimeFormatter = RelativeDateTimeFormatter()
				relativeDateTimeFormatter.dateTimeStyle = .named
				//relativeDateTimeFormatter.formattingContext = .dynamic
				let refreshed = relativeDateTimeFormatter.localizedString(for: accountLastArticleFetchEndTime, relativeTo: Date())
				let localizedRefreshText = NSLocalizedString("Updated %@", comment: "Updated")
				let refreshText = NSString.localizedStringWithFormat(localizedRefreshText as NSString, refreshed) as String
				label.text = refreshText.prefix(1).capitalized + refreshText.dropFirst()
				
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

	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		// This hack is probably necessary because custom views in the toolbar don't get
		// notifications that the content size changed.
		label.font = UIFont.preferredFont(forTextStyle: .footnote)
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
}

// MARK: Private

private extension RefreshProgressView {

	func progressChanged() {
		// Layout may crash if not in the view hierarchy.
		// https://github.com/Ranchero-Software/NetNewsWire/issues/1764
		let isInViewHierarchy = self.superview != nil

		let progress = AccountManager.shared.combinedRefreshProgress
		
		if progress.isComplete {
			if isInViewHierarchy {
				progressView.setProgress(1, animated: true)
			}
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				self.updateRefreshLabel()
				self.label.isHidden = false
				self.progressView.isHidden = true
				self.progressWidthConstraint.isActive = false
				if isInViewHierarchy {
					self.progressView.setProgress(0, animated: true)
				}
			}
		} else {
			label.isHidden = true
			progressView.isHidden = false
			progressWidthConstraint.isActive = true
			if isInViewHierarchy {
				progressView.setNeedsLayout()
				progressView.layoutIfNeeded()
				let percent = Float(progress.numberCompleted) / Float(progress.numberOfTasks)

				// Don't let the progress bar go backwards unless we need to go back more than 25%
				if percent > progressView.progress || progressView.progress - percent > 0.25 {
					progressView.setProgress(percent, animated: true)
				}
			}
		}
	}
	
	func scheduleUpdateRefreshLabel() {
		DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
			self?.updateRefreshLabel()
			self?.scheduleUpdateRefreshLabel()
		}
	}
	
}
