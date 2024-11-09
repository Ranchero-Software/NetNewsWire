//
//  RSHTMLMetadataParser.m
//  RSParser
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RSHTMLMetadataParser.h"
#import "RSHTMLMetadata.h"
#import "RSSAXHTMLParser.h"
#import "RSSAXHTMLParser.h"
#import "RSSAXParser.h"
#import "RSParserInternal.h"
#import "ParserData.h"
#import "RSHTMLTag.h"

#import <libxml/xmlstring.h>


@interface RSHTMLMetadataParser () <RSSAXHTMLParserDelegate>

@property (nonatomic, readonly) ParserData *parserData;
@property (nonatomic, readwrite) RSHTMLMetadata *metadata;
@property (nonatomic) NSMutableArray *tags;
@property (nonatomic) BOOL didFinishParsing;
@property (nonatomic) BOOL shouldScanPastHeadSection;

@end


@implementation RSHTMLMetadataParser


#pragma mark - Class Methods

+ (RSHTMLMetadata *)HTMLMetadataWithParserData:(ParserData *)parserData {

	RSHTMLMetadataParser *parser = [[self alloc] initWithParserData:parserData];
	return parser.metadata;
}


#pragma mark - Init

- (instancetype)initWithParserData:(ParserData *)parserData {

	NSParameterAssert(parserData.data);
	NSParameterAssert(parserData.url);

	self = [super init];
	if (!self) {
		return nil;
	}

	_parserData = parserData;
	_tags = [NSMutableArray new];

	// YouTube has a weird bug where, on some pages, it puts the feed link tag after the head section, in the body section.
	// This allows for a special case where we continue to scan after the head section.
	// (Yes, this match could yield false positives, but it’s harmless.)
	_shouldScanPastHeadSection = [parserData.url rangeOfString:@"youtube" options:NSCaseInsensitiveSearch].location != NSNotFound;

	[self parse];

	return self;
}


#pragma mark - Parse

- (void)parse {

	RSSAXHTMLParser *parser = [[RSSAXHTMLParser alloc] initWithDelegate:self];
	[parser parseData:self.parserData.data];
	[parser finishParsing];

	self.metadata = [[RSHTMLMetadata alloc] initWithURLString:self.parserData.url tags:self.tags];
}


static NSString *kHrefKey = @"href";
static NSString *kSrcKey = @"src";
static NSString *kRelKey = @"rel";

- (NSString *)linkForDictionary:(NSDictionary *)d {

	NSString *link = [d rsparser_objectForCaseInsensitiveKey:kHrefKey];
	if (link) {
		return link;
	}

	return [d rsparser_objectForCaseInsensitiveKey:kSrcKey];
}

- (void)handleLinkAttributes:(NSDictionary *)d {

	if (RSParserStringIsEmpty([d rsparser_objectForCaseInsensitiveKey:kRelKey])) {
		return;
	}
	if (RSParserStringIsEmpty([self linkForDictionary:d])) {
		return;
	}

	RSHTMLTag *tag = [RSHTMLTag linkTagWithAttributes:d];
	[self.tags addObject:tag];
}

- (void)handleMetaAttributes:(NSDictionary *)d {

	RSHTMLTag *tag = [RSHTMLTag metaTagWithAttributes:d];
	[self.tags addObject:tag];
}

#pragma mark - RSSAXHTMLParserDelegate

static const char *kBody = "body";
static const NSInteger kBodyLength = 5;
static const char *kLink = "link";
static const NSInteger kLinkLength = 5;
static const char *kMeta = "meta";
static const NSInteger kMetaLength = 5;

- (void)saxParser:(RSSAXHTMLParser *)SAXParser XMLStartElement:(const xmlChar *)localName attributes:(const xmlChar **)attributes {

	if (self.didFinishParsing) {
		return;
	}
	
	if (RSSAXEqualTags(localName, kBody, kBodyLength) && !self.shouldScanPastHeadSection) {
		self.didFinishParsing = YES;
		return;
	}

	if (RSSAXEqualTags(localName, kLink, kLinkLength)) {
		NSDictionary *d = [SAXParser attributesDictionary:attributes];
		if (!RSParserObjectIsEmpty(d)) {
			[self handleLinkAttributes:d];
		}
		return;
	}

	if (RSSAXEqualTags(localName, kMeta, kMetaLength)) {
		NSDictionary *d = [SAXParser attributesDictionary:attributes];
		if (!RSParserObjectIsEmpty(d)) {
			[self handleMetaAttributes:d];
		}
	}
}

@end
