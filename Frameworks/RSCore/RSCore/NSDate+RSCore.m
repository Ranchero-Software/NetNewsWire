//
//  NSDate+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "NSDate+RSCore.h"

@implementation NSDate (RSCore)


- (NSString *)rs_unixTimestampStringWithNoDecimal {
	return [NSString stringWithFormat:@"%.0f", [self timeIntervalSince1970]]; /*%.0f means no decimal*/
}


- (NSString *)rs_iso8601DateString {

	/*NSDateFormatters are not thread-safe.*/

	static NSDateFormatter *dateFormatter = nil;
	static NSLock *lock = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		lock = [[NSLock alloc] init];
		dateFormatter = [NSDateFormatter new];
		NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
		[dateFormatter setLocale:enUSPOSIXLocale];
		[dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"];
	});

	[lock lock];
	NSString *dateString = [dateFormatter stringFromDate:self];
	[lock unlock];
	
	return dateString;
}


+ (NSDate *)rs_dateWithNumberOfDaysInThePast:(NSUInteger)numberOfDays {

	NSTimeInterval timeInterval = 60 * 60 * 24 * numberOfDays;
	return [NSDate dateWithTimeIntervalSinceNow:-timeInterval];
}

@end
