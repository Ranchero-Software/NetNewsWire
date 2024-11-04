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
	
	public func addChildAndPin(_ view: UIView) {
		view.translatesAutoresizingMaskIntoConstraints = false
		addSubview(view)
		
		NSLayoutConstraint.activate([
			safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			safeAreaLayoutGuide.topAnchor.constraint(equalTo: view.topAnchor),
			safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
		
	}
	
    public func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
	
}
#endif
