//
//  NSString+ExtrasTests.m
//  RSCore
//
//  Created by Brent Simmons on 1/27/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
@import RSCore;

@interface NSString_ExtrasTests : XCTestCase

@end

@implementation NSString_ExtrasTests

- (void)testTrimmingWhitespace {
	
	NSString *s = @"\tfoo\n\n\t\r\t";
	NSString *result = [s rs_stringByTrimmingWhitespace];
	XCTAssertEqualObjects(result, @"foo");

	s = @"\t\n\n\t\r\t";
	result = [s rs_stringByTrimmingWhitespace];
	XCTAssertEqualObjects(result, @"");

	s = @"\t";
	result = [s rs_stringByTrimmingWhitespace];
	XCTAssertEqualObjects(result, @"");

	s = @"";
	result = [s rs_stringByTrimmingWhitespace];
	XCTAssertEqualObjects(result, @"");

	s = @"\nfoo\n";
	result = [s rs_stringByTrimmingWhitespace];
	XCTAssertEqualObjects(result, @"foo");

	s = @"\nfoo";
	result = [s rs_stringByTrimmingWhitespace];
	XCTAssertEqualObjects(result, @"foo");

	s = @"foo\n";
	result = [s rs_stringByTrimmingWhitespace];
	XCTAssertEqualObjects(result, @"foo");

	s = @"fo\n\n\n\n\n\no\n";
	result = [s rs_stringByTrimmingWhitespace];
	XCTAssertEqualObjects(result, @"fo\n\n\n\n\n\no");
}

- (void)testMD5HashStringPerformance {

	NSString *s1 = @"These are the times that try men’s souls.";
	NSString *s2 = @"These are the times that men’s souls.";
	NSString *s3 = @"These ar th time that try men’s souls.";
	NSString *s4 = @"These are the times that try men’s.";
	NSString *s5 = @"These are the that try men’s souls.";
	NSString *s6 = @"These are times that try men’s souls.";
	NSString *s7 = @"are the times that try men’s souls.";
	NSString *s8 = @"These the times that try men’s souls.";
	NSString *s9 = @"These are the times tht try men’s souls.";
	NSString *s10 = @"These are the times that try men's souls.";
	
	[self measureBlock:^{
		
		for (NSInteger i = 0; i < 1000; i++) {
			(void)[s1 rs_md5HashString];
			(void)[s2 rs_md5HashString];
			(void)[s3 rs_md5HashString];
			(void)[s4 rs_md5HashString];
			(void)[s5 rs_md5HashString];
			(void)[s6 rs_md5HashString];
			(void)[s7 rs_md5HashString];
			(void)[s8 rs_md5HashString];
			(void)[s9 rs_md5HashString];
			(void)[s10 rs_md5HashString];
		}
	}];
}


@end
