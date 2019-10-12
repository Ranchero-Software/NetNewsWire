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
	@IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
	@IBOutlet weak var imageScrollView: ImageScrollView!
	
	private var dataTask: URLSessionDataTask? = nil
	private var image: UIImage?
	var url: URL!
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
		activityIndicatorView.isHidden = false
		activityIndicatorView.startAnimating()
		
        imageScrollView.setup()
        imageScrollView.imageScrollViewDelegate = self
        imageScrollView.imageContentMode = .aspectFit
        imageScrollView.initialOffset = .center
		
		dataTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
			guard let self = self else { return }
			
			if let data = data, let image = UIImage(data: data) {
				
				self.image = image
				
				DispatchQueue.main.async {
					self.shareButton.isEnabled = true
					self.activityIndicatorView.isHidden = true
					self.activityIndicatorView.stopAnimating()
					self.imageScrollView.display(image: image)
				}
				
			}
			
		}
		
		dataTask!.resume()
    }

	@IBAction func share(_ sender: Any) {
		guard let image = image else { return }
		let activityViewController = UIActivityViewController(activityItems: [url!, image], applicationActivities: nil)
		activityViewController.popoverPresentationController?.sourceView = shareButton
		activityViewController.popoverPresentationController?.sourceRect = shareButton.bounds
		present(activityViewController, animated: true)
	}
	
	@IBAction func done(_ sender: Any) {
		dataTask?.cancel()
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
