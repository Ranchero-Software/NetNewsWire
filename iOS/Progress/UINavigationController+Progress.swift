//
//  UINavigationController+Progress.swift
//  KYNavigationProgress
//
//  Created by kyo__hei on 2015/12/29.
//  Copyright (c) 2015 kyo__hei. All rights reserved.
//
// Original project: https://github.com/ykyouhei/KYNavigationProgress

import UIKit
import Account

private let constraintIdentifier = "progressHeightConstraint"

public extension UINavigationController {
	
	/* ====================================================================== */
	// MARK: - Properties
	/* ====================================================================== */
	
	/**
	Default is 2.0
	*/
	var progressHeight: CGFloat {
		get { return progressView.frame.height }
		set {
			progressView.frame.origin.y = navigationBar.frame.height - newValue
			progressView.frame.size.height = newValue
		}
	}
	
	/**
	The color shown for the portion of the progress bar that is not filled.
	default is clear color.
	*/
	var trackTintColor: UIColor? {
		get { return progressView.trackTintColor }
		set { progressView.trackTintColor = newValue }
	}
	
	/**
	The color shown for the portion of the progress bar that is filled.
	default is (r: 0, g: 122, b: 225, a: 255.
	*/
	var progressTintColor: UIColor? {
		get { return progressView.progressTintColor }
		set { progressView.progressTintColor = newValue }
	}
	
	/**
	The current progress is represented by a floating-point value between 0.0 and 1.0,
	inclusive, where 1.0 indicates the completion of the task. The default value is 0.0.
	*/
	var progress: Float {
		get { return progressView.progress }
		set { progressView.progress = newValue }
	}
	
	
	private var progressView: NavigationProgressView {
		
		for subview in navigationBar.subviews {
			if let progressView = subview as? NavigationProgressView {
				return progressView
			}
		}
		
		let defaultHeight = CGFloat(2)
		let frame = CGRect(
			x: 0,
			y: navigationBar.frame.height - defaultHeight,
			width: navigationBar.frame.width,
			height: defaultHeight
		)
		let progressView = NavigationProgressView(frame: frame)
		
		navigationBar.addSubview(progressView)
		
		progressView.autoresizingMask = [
			.flexibleWidth, .flexibleTopMargin
		]
		
		
		return progressView
	}
	
	
	/* ====================================================================== */
	// MARK: - Public Method
	/* ====================================================================== */
	
	/**
	Adjusts the current progress shown by the receiver, optionally animating the change.
	
	- parameter progress: The new progress value.
	- parameter animated: true if the change should be animated, false if the change should happen immediately.
	*/
	func setProgress(_ progress: Float, animated: Bool, completion: @escaping () -> Void) {
		progressView.bar.alpha = 1
		progressView.setProgress(progress, animated: animated, completion: completion)
	}
	
	/**
	While progress is changed to 1.0, the bar will fade out. After that, progress will be 0.0.
	*/
	func finishProgress() {
		progressView.bar.alpha = 1
		progressView.setProgress(1, animated: true) {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
				UIView.animate(withDuration: 0.5, animations: { self.progressView.bar.alpha = 0 }) { finished in
					self.progressView.progress = 0
				}
			}
		}
	}
	
	/**
	While progress is changed to 0.0, the bar will fade out.
	*/
	func cancelProgress() {
		progressView.setProgress(0, animated: true) {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
				UIView.animate(withDuration: 0.5, animations: {
					self.progressView.bar.alpha = 0
				})
			}
		}
	}
	
	func updateAccountRefreshProgressIndicator() {
		
		let progress = AccountManager.shared.combinedRefreshProgress
		
		if progress.isComplete {
			if self.progress != 0 {
				finishProgress()
			}
		} else {
			let percent = Float(progress.numberCompleted) / Float(progress.numberOfTasks)
			setProgress(percent, animated: true) {}
		}
		
	}
	
}
