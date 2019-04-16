//
//  AddContainerViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/16/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import UIKit

class AddContainerViewController: UIViewController {

	@IBOutlet weak var cancelButton: UIBarButtonItem!
	@IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
	@IBOutlet weak var addButton: UIBarButtonItem!
	@IBOutlet weak var containerView: UIView!
	
	private var currentViewController: UIViewController?
	
	override func viewDidLoad() {
		
        super.viewDidLoad()
		activityIndicatorView.isHidden = true
		
		switchToFeed()
		
    }

	@IBAction func typeSelectorChanged(_ sender: UISegmentedControl) {
		
		switch sender.selectedSegmentIndex {
		case 0:
			switchToFeed()
		case 1:
			switchToFolder()
		default:
			switchToAccount()
		}
		
	}
	
	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true)
	}
	
	@IBAction func add(_ sender: Any) {
	}
	
}

private extension AddContainerViewController {
	
	func switchToFeed() {
		guard !(currentViewController is AddFeedViewController) else {
			return
		}
		hideCurrentController()
		displayContentController(UIStoryboard.add.instantiateController(ofType: AddFeedViewController.self))
	}
	
	func switchToFolder() {
		guard !(currentViewController is AddFolderViewController) else {
			return
		}
		hideCurrentController()
		displayContentController(UIStoryboard.add.instantiateController(ofType: AddFolderViewController.self))
	}
	
	func switchToAccount() {
		guard !(currentViewController is AddAccountViewController) else {
			return
		}
		hideCurrentController()
		displayContentController(UIStoryboard.add.instantiateController(ofType: AddAccountViewController.self))
	}
	
	func displayContentController(_ controller: UIViewController) {
		
		addChild(controller)
		
		containerView.addSubview(controller.view)
		controller.view.translatesAutoresizingMaskIntoConstraints = false
		controller.view.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
		controller.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
		controller.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
		controller.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
		
		controller.didMove(toParent: self)
		
	}
	
	func hideCurrentController() {
		guard let currentViewController = currentViewController else {
			return
		}
		currentViewController.willMove(toParent: nil)
		currentViewController.view.removeFromSuperview()
		currentViewController.removeFromParent()
	}
	
}
