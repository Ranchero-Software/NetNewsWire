//
//  NSTimer+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSTimer+RSCore.h"


@implementation NSTimer (RSCore)


- (void)rs_invalidateIfValid {

	if ([self isValid]) {
		[self invalidate];
	}
}


@end
