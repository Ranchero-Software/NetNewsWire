//
//  RSHTMLMetadataParser.m
//  RSParser
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import <libxml/xmlstring.h>
#import <RSParser/RSHTMLMetadataParser.h>
#import <RSParser/RSHTMLMetadata.h>
#import <RSParser/RSSAXHTMLParser.h>
#import <RSParser/RSSAXParser.h>
#import <RSParser/RSParserInternal.h>
#import <RSParser/ParserData.h>


@interface RSHTMLMetadataParser () <RSSAXHTMLParserDelegate>

@property (nonatomic, readonly) ParserData *parserData;
@property (nonatomic, readwrite) RSHTMLMetadata *metadata;
@property (nonatomic) NSMutableArray *dictionaries;
@property (nonatomic) BOOL didFinishParsing;

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
	_dictionaries = [NSMutableArray new];

	[self parse];

	return self;
}


#pragma mark - Parse

- (void)parse {

	RSSAXHTMLParser *parser = [[RSSAXHTMLParser alloc] initWithDelegate:self];
	[parser parseData:self.parserData.data];
	[parser finishParsing];

	self.metadata = [[RSHTMLMetadata alloc] initWithURLString:self.parserData.url dictionaries:[self.dictionaries copy]];
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

	[self.dictionaries addObject:d];
}


#pragma mark - RSSAXHTMLParserDelegate

static const char *kBody = "body";
static const NSInteger kBodyLength = 5;
static const char *kLink = "link";
static const NSInteger kLinkLength = 5;

- (void)saxParser:(RSSAXHTMLParser *)SAXParser XMLStartElement:(const xmlChar *)localName attributes:(const xmlChar **)attributes {

	if (self.didFinishParsing) {
		return;
	}
	
	if (RSSAXEqualTags(localName, kBody, kBodyLength)) {
		self.didFinishParsing = YES;
		return;
	}

	if (!RSSAXEqualTags(localName, kLink, kLinkLength)) {
		return;
	}

	NSDictionary *d = [SAXParser attributesDictionary:attributes];
	if (!RSParserObjectIsEmpty(d)) {
		[self handleLinkAttributes:d];
	}
}

@end
