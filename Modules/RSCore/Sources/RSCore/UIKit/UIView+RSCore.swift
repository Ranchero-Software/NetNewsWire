//
//  UIView-Extensions.swift
//  RSCore
//
//  Created by Maurice Parker on 4/20/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

#if os(iOS)

import UIKit

extension UIView {

	public func setFrameIfNotEqual(_ rect: CGRect) {
		if !self.frame.equalTo(rect) {
			self.frame = rect
		}
	}

    public func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }

	/// The nearest view controller in the responder chain (may be nil).
	public var enclosingViewController: UIViewController? {
		var responder: UIResponder? = self
		while let currentResponder = responder {
			if let viewController = currentResponder as? UIViewController {
				return viewController
			}
			responder = currentResponder.next
		}
		return nil
	}

	/// True when this view’s split view controller is showing multiple columns —
	/// iPad and large iPhones in landscape.
	public var isInExpandedSplitView: Bool {
		enclosingViewController?.splitViewController?.isCollapsed == false
	}
}

#endif
