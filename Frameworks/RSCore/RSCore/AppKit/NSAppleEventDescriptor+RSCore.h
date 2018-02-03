//
//  NSAppleEventDescriptor+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 1/15/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

@import AppKit;

NS_ASSUME_NONNULL_BEGIN

@interface NSAppleEventDescriptor (RSCore)

+ (NSAppleEventDescriptor * _Nullable)descriptorWithRunningApplication:(NSRunningApplication *)runningApplication;

@end

NS_ASSUME_NONNULL_END
