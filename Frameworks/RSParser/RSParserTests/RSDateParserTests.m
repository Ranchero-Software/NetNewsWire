//
//  RSDateParserTests.m
//  RSParser
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
@import RSParser;

@interface RSDateParserTests : XCTestCase

@end

@implementation RSDateParserTests

static NSDate *dateWithValues(NSInteger year, NSInteger month, NSInteger day, NSInteger hour, NSInteger minute, NSInteger second) {
	
	NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
	dateComponents.calendar = NSCalendar.currentCalendar;
	dateComponents.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
	[dateComponents setValue:year forComponent:NSCalendarUnitYear];
	[dateComponents setValue:month forComponent:NSCalendarUnitMonth];
	[dateComponents setValue:day forComponent:NSCalendarUnitDay];
	[dateComponents setValue:hour forComponent:NSCalendarUnitHour];
	[dateComponents setValue:minute forComponent:NSCalendarUnitMinute];
	[dateComponents setValue:second forComponent:NSCalendarUnitSecond];
	
	return dateComponents.date;
}

- (void)testDateWithString {
	
	NSDate *expectedDateResult = dateWithValues(2010, 5, 28, 21, 3, 38);
	XCTAssertNotNil(expectedDateResult);

	NSDate *d = RSDateWithString(@"Fri, 28 May 2010 21:03:38 +0000");
	XCTAssertEqualObjects(d, expectedDateResult);

	d = RSDateWithString(@"Fri, 28 May 2010 21:03:38 +00:00");
	XCTAssertEqualObjects(d, expectedDateResult);

	d = RSDateWithString(@"Fri, 28 May 2010 21:03:38 -00:00");
	XCTAssertEqualObjects(d, expectedDateResult);

	d = RSDateWithString(@"Fri, 28 May 2010 21:03:38 -0000");
	XCTAssertEqualObjects(d, expectedDateResult);

	d = RSDateWithString(@"Fri, 28 May 2010 21:03:38 GMT");
	XCTAssertEqualObjects(d, expectedDateResult);

	d = RSDateWithString(@"2010-05-28T21:03:38+00:00");
	XCTAssertEqualObjects(d, expectedDateResult);
	
	d = RSDateWithString(@"2010-05-28T21:03:38+0000");
	XCTAssertEqualObjects(d, expectedDateResult);

	d = RSDateWithString(@"2010-05-28T21:03:38-0000");
	XCTAssertEqualObjects(d, expectedDateResult);

	d = RSDateWithString(@"2010-05-28T21:03:38-00:00");
	XCTAssertEqualObjects(d, expectedDateResult);

	d = RSDateWithString(@"2010-05-28T21:03:38Z");
	XCTAssertEqualObjects(d, expectedDateResult);

	expectedDateResult = dateWithValues(2010, 7, 13, 17, 6, 40);
	d = RSDateWithString(@"2010-07-13T17:06:40+00:00");
	XCTAssertEqualObjects(d, expectedDateResult);

	expectedDateResult = dateWithValues(2010, 4, 30, 12, 0, 0);
	d = RSDateWithString(@"30 Apr 2010 5:00 PDT");
	XCTAssertEqualObjects(d, expectedDateResult);

	expectedDateResult = dateWithValues(2010, 5, 21, 21, 22, 53);
	d = RSDateWithString(@"21 May 2010 21:22:53 GMT");
	XCTAssertEqualObjects(d, expectedDateResult);
	
	expectedDateResult = dateWithValues(2010, 6, 9, 5, 0, 0);
	d = RSDateWithString(@"Wed, 09 Jun 2010 00:00 EST");
	XCTAssertEqualObjects(d, expectedDateResult);

	expectedDateResult = dateWithValues(2010, 6, 23, 3, 43, 50);
	d = RSDateWithString(@"Wed, 23 Jun 2010 03:43:50 Z");
	XCTAssertEqualObjects(d, expectedDateResult);

	expectedDateResult = dateWithValues(2010, 6, 22, 3, 57, 49);
	d = RSDateWithString(@"2010-06-22T03:57:49+00:00");
	XCTAssertEqualObjects(d, expectedDateResult);

	expectedDateResult = dateWithValues(2010, 11, 17, 13, 40, 07);
	d = RSDateWithString(@"2010-11-17T08:40:07-05:00");
	XCTAssertEqualObjects(d, expectedDateResult);
}


@end
