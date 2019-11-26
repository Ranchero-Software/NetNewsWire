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
		
		view.setNeedsLayout()
		view.layoutIfNeeded()
		preferredContentSize = CGSize(width: view.bounds.width, height: dateTimeLabel.frame.maxY + 8)
    }

}
