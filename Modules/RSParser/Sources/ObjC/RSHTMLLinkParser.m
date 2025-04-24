//
//  RSHTMLLinkParser.m
//  RSParser
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//


#import "RSHTMLLinkParser.h"
#import "RSSAXHTMLParser.h"
#import "RSSAXParser.h"
#import "RSParserInternal.h"
#import "ParserData.h"

#import <libxml/xmlstring.h>



@interface RSHTMLLinkParser() <RSSAXHTMLParserDelegate>

@property (nonatomic, readonly) NSMutableArray *links;
@property (nonatomic, readonly) ParserData *parserData;
@property (nonatomic, readonly) NSMutableArray *dictionaries;
@property (nonatomic, readonly) NSURL *baseURL;

@end


@interface RSHTMLLink()

@property (nonatomic, readwrite) NSString *urlString; //absolute
@property (nonatomic, readwrite) NSString *text;
@property (nonatomic, readwrite) NSString *title; //title attribute inside anchor tag

@end


@implementation RSHTMLLinkParser


#pragma mark - Class Methods

+ (NSArray *)htmlLinksWithParserData:(ParserData *)parserData {

	RSHTMLLinkParser *parser = [[self alloc] initWithParserData:parserData];
	return parser.links;
}


#pragma mark - Init

- (instancetype)initWithParserData:(ParserData *)parserData {

	NSParameterAssert(parserData.data);
	NSParameterAssert(parserData.url);

	self = [super init];
	if (!self) {
		return nil;
	}

	_links = [NSMutableArray new];
	_parserData = parserData;
	_dictionaries = [NSMutableArray new];
	_baseURL = [NSURL URLWithString:parserData.url];

	[self parse];

	return self;
}


#pragma mark - Parse

- (void)parse {

	RSSAXHTMLParser *parser = [[RSSAXHTMLParser alloc] initWithDelegate:self];
	[parser parseData:self.parserData.data];
	[parser finishParsing];
}


- (RSHTMLLink *)currentLink {

	return self.links.lastObject;
}


static NSString *kHrefKey = @"href";

- (NSString *)urlStringFromDictionary:(NSDictionary *)d {

	NSString *href = [d rsparser_objectForCaseInsensitiveKey:kHrefKey];
	if (!href) {
		return nil;
	}

	NSURL *absoluteURL = [NSURL URLWithString:href relativeToURL:self.baseURL];
	return absoluteURL.absoluteString;
}


static NSString *kTitleKey = @"title";

- (NSString *)titleFromDictionary:(NSDictionary *)d {

	return [d rsparser_objectForCaseInsensitiveKey:kTitleKey];
}


- (void)handleLinkAttributes:(NSDictionary *)d {

	RSHTMLLink *link = self.currentLink;
	link.urlString = [self urlStringFromDictionary:d];
	link.title = [self titleFromDictionary:d];
}


static const char *kAnchor = "a";
static const NSInteger kAnchorLength = 2;

- (void)saxParser:(RSSAXHTMLParser *)SAXParser XMLStartElement:(const xmlChar *)localName attributes:(const xmlChar **)attributes {

	if (!RSSAXEqualTags(localName, kAnchor, kAnchorLength)) {
		return;
	}

	RSHTMLLink *link = [RSHTMLLink new];
	[self.links addObject:link];

	NSDictionary *d = [SAXParser attributesDictionary:attributes];
	if (!RSParserObjectIsEmpty(d)) {
		[self handleLinkAttributes:d];
	}

	[SAXParser beginStoringCharacters];
}


- (void)saxParser:(RSSAXParser *)SAXParser XMLEndElement:(const xmlChar *)localName {

	if (!RSSAXEqualTags(localName, kAnchor, kAnchorLength)) {
		return;
	}

	self.currentLink.text = SAXParser.currentStringWithTrimmedWhitespace;
}

@end

@implementation RSHTMLLink

@end
