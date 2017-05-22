//
//  RSScaling.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;
@import CoreGraphics;


CGSize RSScaledSizeForImageFittingSize(CGSize imageSize, CGSize constrainingSize); /*does a ceil on size.*/

CGFloat RSZoomScaleToFitSize(CGSize imageSize, CGSize constrainingSize); /*Aspect fit*/
CGFloat RSZoomScaleToFillSize(CGSize imageSize, CGSize constrainingSize); /*Aspect fill*/
