//
//  NSMutableSet+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSMutableSet+RSCore.h"


@implementation NSMutableSet (RSCore)


- (void)rs_safeAddObject:(id)obj {
	if (obj != nil) {
		[self addObject:obj];
	}
}


@end
