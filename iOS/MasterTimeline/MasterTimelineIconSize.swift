//
//  MasterTimelineIconSize.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import CoreGraphics

enum MasterTimelineIconSize: Int, CaseIterable {
	case small = 1
	case medium = 2
	case large = 3
	
	private static let smallDimension = CGFloat(integerLiteral: 24)
	private static let mediumDimension = CGFloat(integerLiteral: 36)
	private static let largeDimension = CGFloat(integerLiteral: 48)

	var size: CGSize {
		switch self {
		case .small:
			return CGSize(width: MasterTimelineIconSize.smallDimension, height: MasterTimelineIconSize.smallDimension)
		case .medium:
			return CGSize(width: MasterTimelineIconSize.mediumDimension, height: MasterTimelineIconSize.mediumDimension)
		case .large:
			return CGSize(width: MasterTimelineIconSize.largeDimension, height: MasterTimelineIconSize.largeDimension)
		}
	}

}
