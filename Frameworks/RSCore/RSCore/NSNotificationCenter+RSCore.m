//
//  NSNotificationCenter+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSNotificationCenter+RSCore.h"


@implementation NSNotificationCenter (RSCore)


- (void)rs_postNotificationNameOnMainThread:(NSString *)notificationName object:(id)obj userInfo:(NSDictionary *)userInfo {

	if (![NSThread isMainThread]) {

		dispatch_async(dispatch_get_main_queue(), ^{

			[self postNotificationName:notificationName object:obj userInfo:userInfo];
		});
	}

	else {
		[self postNotificationName:notificationName object:obj userInfo:userInfo];
	}
}


@end
