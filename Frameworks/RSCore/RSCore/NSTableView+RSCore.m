//
//  NSTableView+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/29/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSTableView+RSCore.h"

@implementation NSTableView (RSCore)


- (void)rs_selectRow:(NSInteger)row {

	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO];
}


- (void)rs_selectRowAndScrollToVisible:(NSInteger)row {
	
	[self rs_selectRow:row];
	[self scrollRowToVisible:row];
}

@end
