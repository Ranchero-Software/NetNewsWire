//
//  NSView+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;


@interface NSView (RSCore)


/*Keeps subview at same size as receiver.*/

- (void)rs_addFullSizeConstraintsForSubview:(NSView *)view;

- (void)rs_setFrameIfNotEqual:(NSRect)r;

@property (nonatomic, readonly) BOOL rs_isOrIsDescendedFromFirstResponder;
@property (nonatomic, readonly) BOOL rs_shouldDrawAsActive;

- (NSRect)rs_rectCenteredVertically:(NSRect)originalRect;

- (NSRect)rs_rectCenteredHorizontally:(NSRect)originalRect;

- (NSRect)rs_rectCentered:(NSRect)originalRect;

- (NSTableView *)rs_enclosingTableView;

@end
