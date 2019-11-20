//
//  PoppableGestureRecognizerDelegate.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//
// https://stackoverflow.com/a/38042863

import UIKit

final class PoppableGestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
	
    weak var navigationController: UINavigationController?
    weak var originalDelegate: UIGestureRecognizerDelegate?

    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(gestureRecognizer(_:shouldReceive:)) {
            return true
        } else if let responds = originalDelegate?.responds(to: aSelector) {
            return responds
        } else {
            return false
        }
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        return originalDelegate
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let nav = navigationController, nav.isNavigationBarHidden, nav.viewControllers.count > 1 {
            return true
        } else if let result = originalDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: touch) {
            return result
        } else {
            return false
        }
    }
}
