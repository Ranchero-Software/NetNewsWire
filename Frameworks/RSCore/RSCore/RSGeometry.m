//
//  RSGeometry.m
//  RSCore
//
//  Created by Brent Simmons on 3/13/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RSGeometry.h"


NSRect RSRectCenteredVerticallyInRect(NSRect originalRect, NSRect containerRect) {

	NSRect r = originalRect;
	r.origin.y = NSMidY(containerRect) - (NSHeight(r) / 2.0);
	r = NSIntegralRect(r);
	r.size = originalRect.size;
	return r;
}


NSRect RSRectCenteredHorizontallyInRect(NSRect originalRect, NSRect containerRect) {

	NSRect r = originalRect;
	r.origin.x = NSMidX(containerRect) - (NSWidth(r) / 2.0);
	r = NSIntegralRect(r);
	r.size = originalRect.size;
	return r;
}


NSRect RSRectCenteredInRect(NSRect originalRect, NSRect containerRect) {

	NSRect r = RSRectCenteredVerticallyInRect(originalRect, containerRect);
	return RSRectCenteredHorizontallyInRect(r, containerRect);
}
