//
//  RSHTMLMetadataParser.m
//  RSXML
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import <libxml/xmlstring.h>
#import "RSHTMLMetadataParser.h"
#import "RSXMLData.h"
#import "RSHTMLMetadata.h"
#import "RSSAXHTMLParser.h"
#import "RSSAXParser.h"
#import "RSXMLInternal.h"


@interface RSHTMLMetadataParser () <RSSAXHTMLParserDelegate>

@property (nonatomic, readonly) RSXMLData *xmlData;
@property (nonatomic, readwrite) RSHTMLMetadata *metadata;
@property (nonatomic) NSMutableArray *dictionaries;
@property (nonatomic) BOOL didFinishParsing;

@end


@implementation RSHTMLMetadataParser


#pragma mark - Class Methods

+ (RSHTMLMetadata *)HTMLMetadataWithXMLData:(RSXMLData *)xmlData {

	RSHTMLMetadataParser *parser = [[self alloc] initWithXMLData:xmlData];
	return parser.metadata;
}


#pragma mark - Init

- (instancetype)initWithXMLData:(RSXMLData *)xmlData {

	NSParameterAssert(xmlData.data);
	NSParameterAssert(xmlData.urlString);

	self = [super init];
	if (!self) {
		return nil;
	}

	_xmlData = xmlData;
	_dictionaries = [NSMutableArray new];

	[self parse];

	return self;
}


#pragma mark - Parse

- (void)parse {

	RSSAXHTMLParser *parser = [[RSSAXHTMLParser alloc] initWithDelegate:self];
	[parser parseData:self.xmlData.data];
	[parser finishParsing];

	self.metadata = [[RSHTMLMetadata alloc] initWithURLString:self.xmlData.urlString dictionaries:[self.dictionaries copy]];
}


static NSString *kHrefKey = @"href";
static NSString *kSrcKey = @"src";
static NSString *kRelKey = @"rel";

- (NSString *)linkForDictionary:(NSDictionary *)d {

	NSString *link = [d rsxml_objectForCaseInsensitiveKey:kHrefKey];
	if (link) {
		return link;
	}

	return [d rsxml_objectForCaseInsensitiveKey:kSrcKey];
}


- (void)handleLinkAttributes:(NSDictionary *)d {

	if (RSXMLStringIsEmpty([d rsxml_objectForCaseInsensitiveKey:kRelKey])) {
		return;
	}
	if (RSXMLStringIsEmpty([self linkForDictionary:d])) {
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
	if (!RSXMLIsEmpty(d)) {
		[self handleLinkAttributes:d];
	}
}

@end
