//
//  SystemMessageViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 7/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class SystemMessageViewController: UIViewController {

	@IBOutlet weak var messageLabel: UILabel!
	var message: String = NSLocalizedString("No Selection", comment: "No Selection")
	
    override func viewDidLoad() {
        super.viewDidLoad()
		messageLabel.text = message
    }

}
