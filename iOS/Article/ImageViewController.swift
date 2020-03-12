//
//  ImageViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class ImageViewController: UIViewController {

	
	@IBOutlet weak var closeButton: UIButton!
	@IBOutlet weak var shareButton: UIButton!
	@IBOutlet weak var imageScrollView: ImageScrollView!
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var titleBackground: UIVisualEffectView!
	@IBOutlet weak var titleLeading: NSLayoutConstraint!
	@IBOutlet weak var titleTrailing: NSLayoutConstraint!
	
	var image: UIImage!
	var imageTitle: String?
	var zoomedFrame: CGRect {
		return imageScrollView.zoomedFrame
	}
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
		closeButton.imageView?.contentMode = .scaleAspectFit
		
        imageScrollView.setup()
        imageScrollView.imageScrollViewDelegate = self
        imageScrollView.imageContentMode = .aspectFit
        imageScrollView.initialOffset = .center
		imageScrollView.display(image: image)
		
		titleLabel.text = imageTitle ?? ""
		layoutTitleLabel()
		
		guard imageTitle != "" else {
			titleBackground.removeFromSuperview()
			return
		}
		titleBackground.layer.cornerRadius = 6
    }

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		coordinator.animate(alongsideTransition: { [weak self] context in
			self?.imageScrollView.resize()
		})
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
	
	private func layoutTitleLabel(){
		let width = view.frame.width
		let multiplier = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(0.1) : CGFloat(0.04)
		titleLeading.constant += width * multiplier
		titleTrailing.constant -= width * multiplier
		titleLabel.layoutIfNeeded()
	}
}

// MARK: ImageScrollViewDelegate

extension ImageViewController: ImageScrollViewDelegate {

	func imageScrollViewDidGestureSwipeUp(imageScrollView: ImageScrollView) {
		dismiss(animated: true)
	}
	
	func imageScrollViewDidGestureSwipeDown(imageScrollView: ImageScrollView) {
		dismiss(animated: true)
	}
	
	
}
