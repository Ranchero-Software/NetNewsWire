//
//  NSAppleEventDescriptor+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 1/15/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

#import "NSAppleEventDescriptor+RSCore.h"

@implementation NSAppleEventDescriptor (RSCore)

+ (NSAppleEventDescriptor * _Nullable)descriptorWithRunningApplication:(NSRunningApplication *)runningApplication {

	pid_t processIdentifier = runningApplication.processIdentifier;
	if (processIdentifier == -1) {
		return nil;
	}

	return [NSAppleEventDescriptor descriptorWithProcessIdentifier:processIdentifier];
}

@end
