//
//  RSHTMLTests.m
//  RSXML
//
//  Created by Brent Simmons on 3/5/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import RSXML;
#import <XCTest/XCTest.h>

@interface RSHTMLTests : XCTestCase

@end

@implementation RSHTMLTests


+ (RSXMLData *)xmlData:(NSString *)title urlString:(NSString *)urlString {

	NSString *s = [[NSBundle bundleForClass:[self class]] pathForResource:title ofType:@"html"];
	NSData *d = [[NSData alloc] initWithContentsOfFile:s];
	return [[RSXMLData alloc] initWithData:d urlString:urlString];
}


+ (RSXMLData *)daringFireballData {

	static RSXMLData *xmlData = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		xmlData = [self xmlData:@"DaringFireball" urlString:@"http://daringfireball.net/"];
	});

	return xmlData;
}


+ (RSXMLData *)furboData {

	static RSXMLData *xmlData = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		xmlData = [self xmlData:@"furbo" urlString:@"http://furbo.org/"];
	});

	return xmlData;
}


+ (RSXMLData *)inessentialData {

	static RSXMLData *xmlData = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		xmlData = [self xmlData:@"inessential" urlString:@"http://inessential.com/"];
	});

	return xmlData;
}


+ (RSXMLData *)sixcolorsData {

	static RSXMLData *xmlData = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		xmlData = [self xmlData:@"sixcolors" urlString:@"https://sixcolors.com/"];
	});

	return xmlData;
}


- (void)testDaringFireball {

	RSXMLData *xmlData = [[self class] daringFireballData];
	RSHTMLMetadata *metadata = [RSHTMLMetadataParser HTMLMetadataWithXMLData:xmlData];

	XCTAssertEqualObjects(metadata.faviconLink, @"http://daringfireball.net/graphics/favicon.ico?v=005");

	XCTAssertTrue(metadata.feedLinks.count == 1);
	RSHTMLMetadataFeedLink *feedLink = metadata.feedLinks[0];
	XCTAssertNil(feedLink.title);
	XCTAssertEqualObjects(feedLink.type, @"application/atom+xml");
	XCTAssertEqualObjects(feedLink.urlString, @"http://daringfireball.net/feeds/main");
}


- (void)testDaringFireballPerformance {

	RSXMLData *xmlData = [[self class] daringFireballData];

	[self measureBlock:^{
		(void)[RSHTMLMetadataParser HTMLMetadataWithXMLData:xmlData];
	}];
}

- (void)testFurbo {

	RSXMLData *xmlData = [[self class] furboData];
	RSHTMLMetadata *metadata = [RSHTMLMetadataParser HTMLMetadataWithXMLData:xmlData];

	XCTAssertEqualObjects(metadata.faviconLink, @"http://furbo.org/favicon.ico");

	XCTAssertTrue(metadata.feedLinks.count == 1);
	RSHTMLMetadataFeedLink *feedLink = metadata.feedLinks[0];
	XCTAssertEqualObjects(feedLink.title, @"Iconfactory News Feed");
	XCTAssertEqualObjects(feedLink.type, @"application/rss+xml");
}


- (void)testFurboPerformance {

	RSXMLData *xmlData = [[self class] furboData];

	[self measureBlock:^{
		(void)[RSHTMLMetadataParser HTMLMetadataWithXMLData:xmlData];
	}];
}


- (void)testInessential {

	RSXMLData *xmlData = [[self class] inessentialData];
	RSHTMLMetadata *metadata = [RSHTMLMetadataParser HTMLMetadataWithXMLData:xmlData];

	XCTAssertNil(metadata.faviconLink);

	XCTAssertTrue(metadata.feedLinks.count == 1);
	RSHTMLMetadataFeedLink *feedLink = metadata.feedLinks[0];
	XCTAssertEqualObjects(feedLink.title, @"RSS");
	XCTAssertEqualObjects(feedLink.type, @"application/rss+xml");
	XCTAssertEqualObjects(feedLink.urlString, @"http://inessential.com/xml/rss.xml");

	XCTAssertEqual(metadata.appleTouchIcons.count, 0);
}


- (void)testInessentialPerformance {

	RSXMLData *xmlData = [[self class] inessentialData];

	[self measureBlock:^{
		(void)[RSHTMLMetadataParser HTMLMetadataWithXMLData:xmlData];
	}];
}


- (void)testSixcolors {

	RSXMLData *xmlData = [[self class] sixcolorsData];
	RSHTMLMetadata *metadata = [RSHTMLMetadataParser HTMLMetadataWithXMLData:xmlData];

	XCTAssertEqualObjects(metadata.faviconLink, @"https://sixcolors.com/images/favicon.ico");

	XCTAssertTrue(metadata.feedLinks.count == 1);
	RSHTMLMetadataFeedLink *feedLink = metadata.feedLinks[0];
	XCTAssertEqualObjects(feedLink.title, @"RSS");
	XCTAssertEqualObjects(feedLink.type, @"application/rss+xml");
	XCTAssertEqualObjects(feedLink.urlString, @"http://feedpress.me/sixcolors");

	XCTAssertEqual(metadata.appleTouchIcons.count, 6);
	RSHTMLMetadataAppleTouchIcon *icon = metadata.appleTouchIcons[3];
	XCTAssertEqualObjects(icon.rel, @"apple-touch-icon");
	XCTAssertEqualObjects(icon.sizes, @"120x120");
	XCTAssertEqualObjects(icon.urlString, @"https://sixcolors.com/apple-touch-icon-120.png");
}


- (void)testSixcolorsPerformance {

	RSXMLData *xmlData = [[self class] sixcolorsData];

	[self measureBlock:^{
		(void)[RSHTMLMetadataParser HTMLMetadataWithXMLData:xmlData];
	}];
}

#pragma mark - Links

- (void)testSixColorsLinks {

	RSXMLData *xmlData = [[self class] sixcolorsData];
	NSArray *links = [RSHTMLLinkParser htmlLinksWithData:xmlData];
	
	NSString *linkToFind = @"https://www.theincomparable.com/theincomparable/290/index.php";
	NSString *textToFind = @"this week’s episode of The Incomparable";
	
	BOOL found = NO;
	for (RSHTMLLink *oneLink in links) {
		
		if ([oneLink.urlString isEqualToString:linkToFind] && [oneLink.text isEqualToString:textToFind]) {
			found = YES;
			break;
		}
	}
	
	XCTAssertTrue(found, @"Expected link should have been found.");
	XCTAssertEqual(links.count, 131, @"Expected 131 links.");
}


- (void)testSixColorsLinksPerformance {
	
	RSXMLData *xmlData = [[self class] sixcolorsData];
	
	[self measureBlock:^{
		(void)[RSHTMLLinkParser htmlLinksWithData:xmlData];
	}];
}

@end

