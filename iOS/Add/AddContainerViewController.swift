//
//  AddContainerViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/16/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import UIKit

protocol AddContainerViewControllerChild: UIViewController {
	var delegate: AddContainerViewControllerChildDelegate? {get set}
	func cancel()
	func add()
}

protocol AddContainerViewControllerChildDelegate: UIViewController {
	func readyToAdd(state: Bool)
	func processingDidBegin()
	func processingDidCancel()
	func processingDidEnd()
}

class AddContainerViewController: UIViewController {

	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 400.0)
	
	@IBOutlet weak var cancelButton: UIBarButtonItem!
	@IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
	@IBOutlet weak var addButton: UIBarButtonItem!
	@IBOutlet weak var typeSelectorSegmentedControl: UISegmentedControl!
	@IBOutlet weak var containerView: UIView!
	
	private var currentViewController: AddContainerViewControllerChild?
	
	var initialControllerType: AddControllerType?
	var initialFeed: String?
	var initialFeedName: String?
	
	override func viewDidLoad() {
		
        super.viewDidLoad()
		activityIndicatorView.isHidden = true

		typeSelectorSegmentedControl.selectedSegmentIndex = initialControllerType?.rawValue ?? 0
		switch initialControllerType {
		case .feed:
			switchToFeed()
		case .folder:
			switchToFolder()
		default:
			assertionFailure()
		}
		
    }

	@IBAction func typeSelectorChanged(_ sender: UISegmentedControl) {
		switch sender.selectedSegmentIndex {
		case 0:
			switchToFeed()
		default:
			switchToFolder()
		}
	}
	
	@IBAction func cancel(_ sender: Any) {
		currentViewController?.cancel()
		dismiss(animated: true)
	}
	
	@IBAction func add(_ sender: Any) {
		currentViewController?.add()
	}
	
}

extension AddContainerViewController: AddContainerViewControllerChildDelegate {
	
	func readyToAdd(state: Bool) {
		addButton.isEnabled = state
	}
	
	func processingDidBegin() {
		addButton.isEnabled = false
		typeSelectorSegmentedControl.isEnabled = false
		activityIndicatorView.isHidden = false
		activityIndicatorView.startAnimating()
	}
	
	func processingDidCancel() {
		addButton.isEnabled = true
		typeSelectorSegmentedControl.isEnabled = true
		activityIndicatorView.isHidden = true
		activityIndicatorView.stopAnimating()
	}
	
	func processingDidEnd() {
		dismiss(animated: true)
	}

}

private extension AddContainerViewController {
	
	func switchToFeed() {
		
		guard !(currentViewController is AddFeedViewController) else {
			return
		}
		
		resetUI()
		hideCurrentController()
		
		let addFeedController = UIStoryboard.add.instantiateController(ofType: AddFeedViewController.self)
		addFeedController.initialFeed = initialFeed
		addFeedController.initialFeedName = initialFeedName

		displayContentController(addFeedController)
		
	}
	
	func switchToFolder() {
		
		guard !(currentViewController is AddFolderViewController) else {
			return
		}
		
		resetUI()
		hideCurrentController()
		displayContentController(UIStoryboard.add.instantiateController(ofType: AddFolderViewController.self))
		
	}
	
	func resetUI() {
		addButton.isEnabled = false
	}
	
	func displayContentController(_ controller: AddContainerViewControllerChild) {
		
		currentViewController = controller
		controller.delegate = self
		
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
