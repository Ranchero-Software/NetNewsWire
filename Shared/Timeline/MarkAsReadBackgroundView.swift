//
//  MarkAsReadPullUpViewController.swift
//  NetNewsWire
//
//  Created by Rob Everhardt on 08-11-2021.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//
//  When used as background view for a UITableViewController, will
//  add a pull-up view at the bottom of the table

import UIKit

class MarkAsReadBackgroundView: UIView {
	@IBOutlet weak var pullUpView: UIView!
	
	@IBOutlet weak var label: UILabel!
	
	@IBOutlet weak var heightConstraint: NSLayoutConstraint!
	
	@IBOutlet weak var bottomOffetConstraint: NSLayoutConstraint!
	
	var thresholdHeight: CGFloat = 40.0
	
	var isMarkingAsRead: Bool = false {
		didSet {
			updateLabel()
		}
	}
	
	var height: CGFloat = 50 {
		didSet {
			heightConstraint.constant = height
			updateLabel()
		}
	}
	
	
	private func updateLabel() {
		if isMarkingAsRead {
			label.text = "Marking as read..."
			label.textColor = tintColor
			label.layer.opacity = 1
		} else if height >= thresholdHeight {
			label.text = "Release to mark visible articles as read"
			label.textColor = tintColor
			label.layer.opacity = 1
		} else {
			label.text = "Pull up to mark visible articles as read"
			label.textColor = UIColor.label
			label.layer.opacity = Float(max(0, height / thresholdHeight))
		}
	}
	
	var bottomOffset: CGFloat = 50 {
		didSet {
			bottomOffetConstraint.constant = bottomOffset
		}
	}
}
