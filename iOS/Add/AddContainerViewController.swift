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
	@IBOutlet weak var typeSelectorContainer: UIView!
	@IBOutlet weak var typeSelectorSegmentedControl: UISegmentedControl!
	@IBOutlet weak var containerView: UIView!
	
	private var currentViewController: AddContainerViewControllerChild?
	
	var initialControllerType: AddControllerType?
	var initialFeed: String?
	var initialFeedName: String?
	
	override func viewDidLoad() {
		
        super.viewDidLoad()
		activityIndicatorView.color = UIColor.label
		activityIndicatorView.isHidden = true

		typeSelectorContainer.layer.cornerRadius = 10
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
		
		guard !(currentViewController is AddWebFeedViewController) else {
			return
		}
		
		navigationItem.title = NSLocalizedString("Add Web Feed", comment: "Add Web Feed")
		resetUI()
		
		let addFeedController = UIStoryboard.add.instantiateController(ofType: AddWebFeedViewController.self)
		addFeedController.initialFeed = initialFeed
		addFeedController.initialFeedName = initialFeedName

		displayContentController(addFeedController)
		
	}
	
	func switchToFolder() {
		
		guard !(currentViewController is AddFolderViewController) else {
			return
		}
		
		navigationItem.title = NSLocalizedString("Add Folder", comment: "Add Folder")
		resetUI()
		displayContentController(UIStoryboard.add.instantiateController(ofType: AddFolderViewController.self))
		
	}
	
	func resetUI() {
		addButton.isEnabled = false
	}
	
	func displayContentController(_ controller: AddContainerViewControllerChild) {
		controller.delegate = self
		
		if let currentViewController = currentViewController {
			
			let transition = CATransition()
			transition.type = .push
			transition.subtype = currentViewController is AddWebFeedViewController ? .fromRight : .fromLeft
			containerView.layer.add(transition, forKey: "transition")

			containerView.addChildAndPin(controller.view)
			addChild(controller)
			controller.didMove(toParent: self)

			currentViewController.willMove(toParent: nil)
			currentViewController.view.removeFromSuperview()
			currentViewController.removeFromParent()

		} else {
			
			containerView.addChildAndPin(controller.view)
			addChild(controller)
			controller.didMove(toParent: self)

		}
		
		currentViewController = controller
	}
		
}
