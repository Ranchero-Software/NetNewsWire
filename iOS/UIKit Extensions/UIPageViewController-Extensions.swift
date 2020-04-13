//
//  UIPageViewController-Extensions.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/12/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

extension UIPageViewController {
	
	var scrollViewInsidePageControl: UIScrollView? {
		for view in view.subviews {
			if let scrollView = view as? UIScrollView {
				return scrollView
			}
		}
		return nil
	}
	
}
