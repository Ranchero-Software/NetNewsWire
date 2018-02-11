//
//  NSView+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSView+RSCore.h"
#import "RSGeometry.h"


@implementation NSView (RSCore)


- (void)rs_addFullSizeConstraintsForSubview:(NSView *)view {

	NSDictionary *d = NSDictionaryOfVariableBindings(view);

	NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[view]-0-|" options:0 metrics:nil views:d];
	[self addConstraints:constraints];
	constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[view]-0-|" options:0 metrics:nil views:d];
	[self addConstraints:constraints];
}


- (void)rs_setFrameIfNotEqual:(NSRect)r {

	if (!NSEqualRects(self.frame, r)) {
		self.frame = r;
	}
}


- (BOOL)rs_isOrIsDescendedFromFirstResponder {

	NSView *firstResponder = (NSView *)(self.window.firstResponder);
	if (![firstResponder isKindOfClass:[NSView class]]) {
		return NO;
	}

	return [self isDescendantOf:firstResponder];
}


- (BOOL)rs_shouldDrawAsActive {

	return self.window.isMainWindow && self.rs_isOrIsDescendedFromFirstResponder;
}


- (NSRect)rs_rectCenteredVertically:(NSRect)originalRect {

	return RSRectCenteredVerticallyInRect(originalRect, self.bounds);
}

- (NSRect)rs_rectCenteredHorizontally:(NSRect)originalRect {

	return RSRectCenteredHorizontallyInRect(originalRect, self.bounds);
}

- (NSRect)rs_rectCentered:(NSRect)originalRect {

	return RSRectCenteredInRect(originalRect, self.bounds);
}


- (NSTableView *)rs_enclosingTableView {

	NSView *nomad = self.superview;

	while (nomad != nil) {
		if ([nomad isKindOfClass:[NSTableView class]]) {
			return (NSTableView *)nomad;
		}
		nomad = nomad.superview;
	}

	return nil;
}

@end
