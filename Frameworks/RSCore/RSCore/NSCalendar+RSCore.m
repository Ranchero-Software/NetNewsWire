//
//  NSCalendar+RSCore.m
//  RSCore
//
//  Created by Brent Simmons on 1/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;
#import "NSCalendar+RSCore.h"
#if TARGET_OS_IPHONE
@import UIKit;
#else
@import AppKit;
#endif

@implementation NSCalendar (RSCore)

static NSCalendar *cachedCalendar = nil;

+ (NSCalendar *)rs_cachedCalendar {
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		cachedCalendar = [NSCalendar autoupdatingCurrentCalendar];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rs_significantTimeChange:) name:NSSystemTimeZoneDidChangeNotification object:nil];
		
#if TARGET_OS_IPHONE
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rs_significantTimeChange:) name:UIApplicationDidBecomeActiveNotification object:nil];
#else
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rs_significantTimeChange:) name:NSApplicationDidBecomeActiveNotification object:nil];
#endif
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rs_significantTimeChange:) name:NSCalendarDayChangedNotification object:nil];
	});
	
	NSLock *lock = [self rs_cachedCalendarLock];
	[lock lock];
	NSCalendar *calendar = cachedCalendar;
	[lock unlock];
	
	return calendar;
}


+ (void)rs_significantTimeChange:(NSNotification *)note {
	
#pragma unused(note)
	
	NSLock *lock = [self rs_cachedCalendarLock];
	[lock lock];
	cachedCalendar = [NSCalendar autoupdatingCurrentCalendar];
	[lock unlock];
}

+ (NSLock *)rs_cachedCalendarLock {
	
	static NSLock *lock = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		lock = [[NSLock alloc] init];
	});
	
	return lock;
}


+ (BOOL)rs_dateIsToday:(NSDate *)d {
	
	return [[self rs_cachedCalendar] isDateInToday:d];
}


+ (NSDate *)rs_startOfToday {

	return [[self rs_cachedCalendar] startOfDayForDate:[NSDate date]];
}

@end
