//
//  ImageViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class ImageViewController: UIViewController {
	@IBOutlet var imageScrollView: ImageScrollView!
	@IBOutlet var titleLabel: UILabel!
	@IBOutlet var titleBackground: UIVisualEffectView!
	@IBOutlet var titleLeading: NSLayoutConstraint!
	@IBOutlet var titleTrailing: NSLayoutConstraint!

	private var shareButtonItem: UIBarButtonItem?

	var image: UIImage!
	var imageTitle: String?
	var zoomedFrame: CGRect {
		return imageScrollView.zoomedFrame
	}

	override var keyCommands: [UIKeyCommand]? {
		return [
			UIKeyCommand(
				title: NSLocalizedString("Close Image", comment: "Close Image"),
				action: #selector(done(_:)),
				input: " "
			)
		]
	}

	override func viewDidLoad() {
        super.viewDidLoad()

		let closeButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(done(_:)))
		closeButtonItem.tintColor = Assets.Colors.primaryAccent
		let shareButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share(_:)))
		shareButtonItem.tintColor = Assets.Colors.primaryAccent
		navigationItem.leftBarButtonItem = closeButtonItem
		navigationItem.rightBarButtonItem = shareButtonItem
		self.shareButtonItem = shareButtonItem

        imageScrollView.setup()
        // The image viewer is full-screen, so the scroll view ignores
        // the navigation bar and safe area insets. Otherwise the image is pushed down
        // and doesn’t match the zoom transition’s target frame.
        imageScrollView.contentInsetAdjustmentBehavior = .never
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
		coordinator.animate(alongsideTransition: { [weak self] _ in
			self?.imageScrollView.resize()
		})
	}

	@IBAction func share(_ sender: Any) {
		guard let image else {
			return
		}
		let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
		activityViewController.popoverPresentationController?.barButtonItem = shareButtonItem
		present(activityViewController, animated: true)
	}

	@IBAction func done(_ sender: Any) {
		dismiss(animated: true)
	}

	private func layoutTitleLabel() {
		let width = view.frame.width
		let multiplier = traitCollection.userInterfaceIdiom == .pad ? CGFloat(0.1) : CGFloat(0.04)
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
