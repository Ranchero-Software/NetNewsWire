//
//  NSTableView+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 3/29/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;


@interface NSTableView (RSCore)


- (void)rs_selectRow:(NSInteger)row;
- (void)rs_selectRowAndScrollToVisible:(NSInteger)row;


@end
