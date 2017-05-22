//
//  NSNotificationCenter+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


@interface NSNotificationCenter (RSCore)


/*Posts immediately if already on the main thread.*/

- (void)rs_postNotificationNameOnMainThread:(NSString *)notificationName object:(id)obj userInfo:(NSDictionary *)userInfo;


@end
