//
//  ContextMenuPreviewViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/25/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Articles

class ContextMenuPreviewViewController: UIViewController {

	@IBOutlet weak var blogNameLabel: UILabel!
	@IBOutlet weak var blogAuthorLabel: UILabel!
	@IBOutlet weak var articleTitleLabel: UILabel!
	@IBOutlet weak var dateTimeLabel: UILabel!
	
	var article: Article!
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
		blogNameLabel.text = article.webFeed?.nameForDisplay ?? ""
		blogAuthorLabel.text = article.byline()
		articleTitleLabel.text = article.title ?? ""
		
		let icon = IconView()
		icon.iconImage = article.iconImage()
		icon.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(icon)
		
		NSLayoutConstraint.activate([
			icon.widthAnchor.constraint(equalToConstant: 48),
			icon.heightAnchor.constraint(equalToConstant: 48),
			icon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
			icon.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20)
		])
		
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .medium
		dateTimeLabel.text = dateFormatter.string(from: article.logicalDatePublished)
		
		// When in landscape the context menu preview will force this controller into a tiny
		// view space.  If it is documented anywhere what that is, I haven't found it.  This
		// set of magic numbers is what I worked out by testing a variety of phones.
		
		let width: CGFloat
		let heightPadding: CGFloat
		if view.bounds.width > view.bounds.height {
			width = 260
			heightPadding = 16
			view.widthAnchor.constraint(equalToConstant: width).isActive = true
		} else {
			width = view.bounds.width
			heightPadding = 8
		}
		
		view.setNeedsLayout()
		view.layoutIfNeeded()
		preferredContentSize = CGSize(width: width, height: dateTimeLabel.frame.maxY + heightPadding)
    }

}
