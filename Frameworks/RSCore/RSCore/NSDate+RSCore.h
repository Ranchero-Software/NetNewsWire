//
//  NSDate+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

@interface NSDate (RSCore)


- (NSString *)rs_unixTimestampStringWithNoDecimal;

- (NSString *)rs_iso8601DateString;


/*Not intended for calendar-perfect use.*/

+ (NSDate *)rs_dateWithNumberOfDaysInThePast:(NSUInteger)numberOfDays;


@end
