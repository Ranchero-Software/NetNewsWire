//
//  NSCalendar+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 1/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface NSCalendar (RSCore)

+ (NSCalendar *)rs_cachedCalendar;
+ (BOOL)rs_dateIsToday:(NSDate *)d;
+ (NSDate *)rs_startOfToday NS_SWIFT_NAME(startOfToday());

@end

NS_ASSUME_NONNULL_END

