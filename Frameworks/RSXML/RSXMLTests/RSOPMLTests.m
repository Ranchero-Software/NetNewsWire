//
//  RSOPMLTests.m
//  RSXML
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
@import RSXML;

@interface RSOPMLTests : XCTestCase

@end

@implementation RSOPMLTests

+ (RSXMLData *)subsData {

	static RSXMLData *xmlData = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSString *s = [[NSBundle bundleForClass:[self class]] pathForResource:@"Subs" ofType:@"opml"];
		NSData *d = [[NSData alloc] initWithContentsOfFile:s];
		xmlData = [[RSXMLData alloc] initWithData:d urlString:@"http://example.org/"];
	});

	return xmlData;
}

- (void)testNotOPML {

	NSString *s = [[NSBundle bundleForClass:[self class]] pathForResource:@"DaringFireball" ofType:@"rss"];
	NSData *d = [[NSData alloc] initWithContentsOfFile:s];
	RSXMLData *xmlData = [[RSXMLData alloc] initWithData:d urlString:@"http://example.org/"];
	RSOPMLParser *parser = [[RSOPMLParser alloc] initWithXMLData:xmlData];
	XCTAssertNotNil(parser.error);

	d = [[NSData alloc] initWithContentsOfFile:@"/System/Library/Kernels/kernel"];
	xmlData = [[RSXMLData alloc] initWithData:d urlString:@"/System/Library/Kernels/kernel"];
	parser = [[RSOPMLParser alloc] initWithXMLData:xmlData];
	XCTAssertNotNil(parser.error);
}


- (void)testSubsPerformance {

	RSXMLData *xmlData = [[self class] subsData];

	[self measureBlock:^{
		(void)[[RSOPMLParser alloc] initWithXMLData:xmlData];
	}];
}


- (void)testSubsStructure {

	RSXMLData *xmlData = [[self class] subsData];

	RSOPMLParser *parser = [[RSOPMLParser alloc] initWithXMLData:xmlData];
	XCTAssertNotNil(parser);

	RSOPMLDocument *document = parser.OPMLDocument;
	XCTAssertNotNil(document);

	[self checkStructureForOPMLItem:document];
}

- (void)checkStructureForOPMLItem:(RSOPMLItem *)item {

	RSOPMLFeedSpecifier *feedSpecifier = item.OPMLFeedSpecifier;

	if (![item isKindOfClass:[RSOPMLDocument class]]) {
		XCTAssertNotNil(item.attributes.opml_text);
	}

	// If it has no children, it should have a feed specifier. The converse is also true.
	BOOL isFolder = (item.children.count > 0);
	if (!isFolder && [item.attributes.opml_title isEqualToString:@"Skip"]) {
		isFolder = YES;
	}

	if (!isFolder) {
		XCTAssertNotNil(feedSpecifier.title);
		XCTAssertNotNil(feedSpecifier.feedURL);
	}
	else {
		XCTAssertNil(feedSpecifier);
		if (![item isKindOfClass:[RSOPMLDocument class]]) {
			XCTAssertNotNil(item.attributes.opml_title);
		}
	}

	if (item.children.count > 0) {
		for (RSOPMLItem *oneItem in item.children) {
			[self checkStructureForOPMLItem:oneItem];
		}
	}
}


@end
