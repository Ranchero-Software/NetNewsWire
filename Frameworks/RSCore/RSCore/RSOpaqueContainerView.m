//
//  RSOpaqueContainerView.m
//  RSCore
//
//  Created by Brent Simmons on 3/27/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSOpaqueContainerView.h"
#import "NSView+RSCore.h"


@implementation RSOpaqueContainerView


+ (BOOL)requiresConstraintBasedLayout {

	return NO;
}


- (NSView *)containedView {

	return self.subviews.firstObject;
}


- (void)setContainedView:(NSView *)containedView {

	[self.subviews makeObjectsPerformSelector:@selector(removeFromSuperviewWithoutNeedingDisplay)];
	[self addSubview:containedView];
	self.needsLayout = YES;
	self.needsDisplay = YES;
}


- (void)layout {

	[self resizeSubviewsWithOldSize:NSZeroSize];
}


- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {

#pragma unused(oldSize)
	
	NSView *subview = self.subviews.firstObject;
	[subview rs_setFrameIfNotEqual:self.bounds];
}


@end
