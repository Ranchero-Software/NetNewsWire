//
//  RSScaling.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSScaling.h"


static CGFloat RSScaleFactorToFillSize(CGSize imageSize, CGSize constrainingSize) {

	if (CGSizeEqualToSize(imageSize, constrainingSize))
		return 1.0f;

	CGFloat scaleFactorHeight = imageSize.height / constrainingSize.height;
	CGFloat scaleFactorWidth = imageSize.width / constrainingSize.width;
	CGFloat scaleFactor = MIN(scaleFactorHeight, scaleFactorWidth);

	return scaleFactor;
}


static CGFloat RSScaleFactorToFitSize(CGSize imageSize, CGSize constrainingSize) {

	if (CGSizeEqualToSize(imageSize, constrainingSize))
		return 1.0f;

	CGFloat scaleFactorHeight = imageSize.height / constrainingSize.height;
	CGFloat scaleFactorWidth = imageSize.width / constrainingSize.width;
	CGFloat scaleFactor = MAX(scaleFactorHeight, scaleFactorWidth);

	return scaleFactor;
}


CGFloat RSZoomScaleToFillSize(CGSize imageSize, CGSize constrainingSize) {

	CGFloat scaleFactor = RSScaleFactorToFillSize(imageSize, constrainingSize);
	return 1.0f / scaleFactor;
}


CGFloat RSZoomScaleToFitSize(CGSize imageSize, CGSize constrainingSize) {

	CGFloat scaleFactor = RSScaleFactorToFitSize(imageSize, constrainingSize);
	return 1.0f / scaleFactor;
}


CGSize RSScaledSizeForImageFittingSize(CGSize imageSize, CGSize constrainingSize) {

	CGFloat scaleFactor = RSScaleFactorToFitSize(imageSize, constrainingSize);
	CGSize scaledSize = CGSizeZero;

	scaledSize.height = ceil(imageSize.height / scaleFactor);
	scaledSize.width = ceil(imageSize.width / scaleFactor);

	return scaledSize;
}
