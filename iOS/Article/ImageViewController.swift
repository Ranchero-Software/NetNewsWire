//
//  ImageViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class ImageViewController: UIViewController {

	@IBOutlet weak var shareButton: UIButton!
	@IBOutlet weak var imageScrollView: ImageScrollView!
	
	var image: UIImage!
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
        imageScrollView.setup()
        imageScrollView.imageScrollViewDelegate = self
        imageScrollView.imageContentMode = .aspectFit
        imageScrollView.initialOffset = .center
		imageScrollView.display(image: image)
    }

	@IBAction func share(_ sender: Any) {
		guard let image = image else { return }
		let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
		activityViewController.popoverPresentationController?.sourceView = shareButton
		activityViewController.popoverPresentationController?.sourceRect = shareButton.bounds
		present(activityViewController, animated: true)
	}
	
	@IBAction func done(_ sender: Any) {
		dismiss(animated: true)
	}
	
}

// MARK: ImageScrollViewDelegate

extension ImageViewController: ImageScrollViewDelegate {

	func imageScrollViewDidChangeOrientation(imageScrollView: ImageScrollView) {
	}
	
	func imageScrollViewDidGestureSwipeUp(imageScrollView: ImageScrollView) {
		dismiss(animated: true)
	}
	
	func imageScrollViewDidGestureSwipeDown(imageScrollView: ImageScrollView) {
		dismiss(animated: true)
	}
	
	
}
