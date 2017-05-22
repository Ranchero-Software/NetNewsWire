//
//  RSEntityTests.m
//  RSXML
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
@import RSXML;

@interface RSEntityTests : XCTestCase

@end

@implementation RSEntityTests


- (void)testInnerAmpersand {
	
	NSString *expectedResult = @"A&P";
	
	NSString *result = [@"A&amp;P" rs_stringByDecodingHTMLEntities];
	XCTAssertEqualObjects(result, expectedResult);
	
	result = [@"A&#038;P" rs_stringByDecodingHTMLEntities];
	XCTAssertEqualObjects(result, expectedResult);

	result = [@"A&#38;P" rs_stringByDecodingHTMLEntities];
	XCTAssertEqualObjects(result, expectedResult);

}

- (void)testSingleEntity {
	
	NSString *result = [@"&infin;" rs_stringByDecodingHTMLEntities];
	XCTAssertEqualObjects(result, @"∞");
	
	result = [@"&#038;" rs_stringByDecodingHTMLEntities];
	XCTAssertEqualObjects(result, @"&");
	
	result = [@"&rsquo;" rs_stringByDecodingHTMLEntities];
	XCTAssertEqualObjects(result, @"’");
}

- (void)testNotEntities {
	
	NSString *s = @"&&\t\nFoo & Bar &0; Baz & 1238 4948 More things &foobar;&";
	NSString *result = [s rs_stringByDecodingHTMLEntities];
	XCTAssertEqualObjects(result, s);
}

- (void)testURLs {
	
	NSString *urlString = @"http://www.nytimes.com/2015/09/05/us/at-west-point-annual-pillow-fight-becomes-weaponized.html?mwrsm=Email&#038;_r=1&#038;pagewanted=all";
	NSString *expectedResult = @"http://www.nytimes.com/2015/09/05/us/at-west-point-annual-pillow-fight-becomes-weaponized.html?mwrsm=Email&_r=1&pagewanted=all";
	
	NSString *result = [urlString rs_stringByDecodingHTMLEntities];
	XCTAssertEqualObjects(result, expectedResult);
}

- (void)testEntityPlusWhitespace {
	
	NSString *s = @"&infin; Permalink";
	NSString *expectedResult = @"∞ Permalink";
	
	NSString *result = [s rs_stringByDecodingHTMLEntities];
	XCTAssertEqualObjects(result, expectedResult);
}

- (void)testNonBreakingSpace {
	
	NSString *s = @"&nbsp;&#160; -- just some spaces";
	NSString *expectedResult = [NSString stringWithFormat:@"%C%C -- just some spaces", 160, 160];
	
	NSString *result = [s rs_stringByDecodingHTMLEntities];
	XCTAssertEqualObjects(result, expectedResult);
}

@end
