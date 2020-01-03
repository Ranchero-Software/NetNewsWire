//
//  AccountRefreshControl.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 1/2/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class AccountRefreshControl: UIRefreshControl {

	var errorHandler: ((Error) -> ())? = nil
	
	init(errorHandler: @escaping (Error) -> ()) {
		super.init()
		self.errorHandler = errorHandler
		addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
	}
	
	required init?(coder: NSCoder) {
		fatalError()
	}
	
	@objc func refreshAccounts(_ sender: Any) {
				
		let checkImageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
		checkImageView.tintColor = .label
		checkImageView.translatesAutoresizingMaskIntoConstraints = false
		addSubview(checkImageView)
		NSLayoutConstraint.activate([
			checkImageView.heightAnchor.constraint(equalToConstant: 35.0),
			checkImageView.widthAnchor.constraint(equalToConstant: 35.0),
			checkImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
			checkImageView.centerYAnchor.constraint(equalTo: centerYAnchor)
		])
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.33) {
			self.endRefreshing()
			checkImageView.removeFromSuperview()

			// This is a hack to make sure that an error dialog doesn't interfere with dismissing the refreshControl.
			// If the error dialog appears too closely to the call to endRefreshing, then the refreshControl never disappears.
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				AccountManager.shared.refreshAll(errorHandler: self.errorHandler!)
			}
		}
	}
	
}
