//
//  NavigationProgressView.swift
//  KYNavigationProgress
//
//  Created by kyo__hei on 2015/12/29.
//  Copyright (c) 2015 kyo__hei. All rights reserved.
//
// Original project: https://github.com/ykyouhei/KYNavigationProgress

import UIKit

public final class NavigationProgressView: UIView {
	
	/* ====================================================================== */
	// MARK: - Properties
	/* ====================================================================== */
	
	internal var progress: Float = 0 {
		didSet {
			progress = min(1, progress)
			barWidthConstraint.constant = bounds.width * CGFloat(progress)
		}
	}
	
	internal let bar = UIView()
	
	@objc public dynamic var progressTintColor: UIColor? = AppAssets.primaryAccentColor {
		didSet {
			bar.backgroundColor = progressTintColor
		}
	}
	
	@objc public dynamic var trackTintColor: UIColor? = .clear {
		didSet {
			backgroundColor = trackTintColor
		}
	}
	
	fileprivate let barWidthConstraint: NSLayoutConstraint
	
	override public var frame: CGRect {
		didSet {
			let tmpProgress = progress
			progress = tmpProgress
		}
	}
	
	/* ====================================================================== */
	// MARK: - initializer
	/* ====================================================================== */
	
	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override init(frame: CGRect) {
		barWidthConstraint = NSLayoutConstraint(
			item: bar,
			attribute: .width,
			relatedBy: .equal,
			toItem: nil,
			attribute: .notAnAttribute,
			multiplier: 1,
			constant: frame.width * CGFloat(progress))
		
		super.init(frame: frame)
		
		let leftConstraint = NSLayoutConstraint(
			item: bar,
			attribute: .left,
			relatedBy: .equal,
			toItem: self,
			attribute: .left,
			multiplier: 1,
			constant: 0)
		
		let bottomConstraint = NSLayoutConstraint(
			item: bar,
			attribute: .bottom,
			relatedBy: .equal,
			toItem: self,
			attribute: .bottom,
			multiplier: 1,
			constant: 0)
		
		let topConstraint = NSLayoutConstraint(
			item: bar,
			attribute: .top,
			relatedBy: .equal,
			toItem: self,
			attribute: .top,
			multiplier: 1,
			constant: 0)
		
		addSubview(bar)
		
		backgroundColor = trackTintColor
		
		bar.backgroundColor = progressTintColor
		bar.translatesAutoresizingMaskIntoConstraints = false
		addConstraints([
			barWidthConstraint,
			leftConstraint,
			topConstraint,
			bottomConstraint])
	}
	
	
	/* ====================================================================== */
	// MARK: - Notification
	/* ====================================================================== */
	
	func deviceDidRotate(_ notification: Notification) {
	}
	
	
	/* ====================================================================== */
	// MARK: - Method
	/* ====================================================================== */
	
	internal func setProgress(_ progress: Float, animated: Bool, completion: @escaping () -> Void) {
		let duration: TimeInterval = animated ? 0.2 : 0
		
		self.progress = progress
		
		UIView.animate(withDuration: duration, animations: { self.layoutIfNeeded() }) { _ in
			completion()
		}
		
	}
	
}
