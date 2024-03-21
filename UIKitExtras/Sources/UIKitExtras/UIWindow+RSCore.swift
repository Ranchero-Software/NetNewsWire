//
//  UIViewController+.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/15/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//
#if os(iOS)
import UIKit

extension UIWindow {
	
	public var topViewController: UIViewController? {
		
		var top = self.rootViewController
		while true {
			if let presented = top?.presentedViewController {
				top = presented
			} else if let nav = top as? UINavigationController {
				top = nav.visibleViewController
			} else if let tab = top as? UITabBarController {
				top = tab.selectedViewController
			} else if let split = top as? UISplitViewController {
				switch split.displayMode {
				case .allVisible:
					top = split.viewControllers.first
				case .primaryHidden:
					top = split.viewControllers.last
				default:
					top = split.viewControllers.first
				}
			} else {
				break
			}
		}
		
		return top
		
	}
	
}
#endif
