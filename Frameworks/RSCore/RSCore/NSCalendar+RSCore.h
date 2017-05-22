//
//  NSCalendar+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 1/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

@interface NSCalendar (RSCore)

+ (NSCalendar *)rs_cachedCalendar;
+ (BOOL)rs_dateIsToday:(NSDate *)d;

@end
