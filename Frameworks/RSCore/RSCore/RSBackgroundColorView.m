//
//  RSBackgroundColorView.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSBackgroundColorView.h"


@implementation RSBackgroundColorView

- (BOOL)isOpaque {

	return YES;
}


//- (BOOL)preservesContentDuringLiveResize {
//
//	return YES;
//}
//
//
//- (BOOL)wantsDefaultClipping {
//
//	return NO;
//}
//
//
//- (void)setFrameSize:(NSSize)newSize {
//
//	if (NSEqualSizes(newSize, self.frame.size)) {
//		return;
//	}
//	[super setFrameSize:newSize];
//
//	if (self.inLiveResize) {
//		NSRect rects[4];
//		NSInteger count = 0;
//		[self getRectsExposedDuringLiveResize:rects count:&count];
//		while (count-- > 0) {
//			[self setNeedsDisplayInRect:rects[count]];
//		}
//	} else {
//		self.needsDisplay = YES;
//	}
//}

- (void)drawRect:(NSRect)r {

//	const NSRect *rects;
//	NSInteger count = 0;
//
//	[self getRectsBeingDrawn:&rects count:&count];
//	if (count < 1) {
//		return;
//	}

	[self.backgroundColor setFill];
	NSRectFill(r);
//	NSRectFillList(rects, count);
}


@end
