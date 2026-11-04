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

	private var shareButtonItem: UIBarButtonItem?
	private var lastImageScrollViewSize = CGSize.zero

	// Title margins as a fraction of the view width.
	private static let regularWidthTitleMarginMultiplier: CGFloat = 0.1
	private static let compactWidthTitleMarginMultiplier: CGFloat = 0.04

	var image: UIImage!
	var imageTitle: String?

	// Strong reference — the navigation controller’s transitioningDelegate is weak,
	// and the transition must outlive the WebViewController that configured it.
	var transition: ImageTransition?
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

		guard imageTitle != "" else {
			titleBackground.removeFromSuperview()
			return
		}
		titleBackground.layer.cornerRadius = 6
    }

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		layoutTitleLabel()
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		let imageScrollViewSize = imageScrollView.bounds.size
		if imageScrollViewSize != lastImageScrollViewSize {
			lastImageScrollViewSize = imageScrollViewSize
			imageScrollView.resize()
		}
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
		let multiplier = traitCollection.horizontalSizeClass == .regular ? Self.regularWidthTitleMarginMultiplier : Self.compactWidthTitleMarginMultiplier
		titleLeading.constant = view.bounds.width * multiplier
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
