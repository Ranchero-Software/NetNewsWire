//
//  RSRSSParser.m
//  RSParser
//
//  Created by Brent Simmons on 1/6/15.
//  Copyright (c) 2015 Ranchero Software LLC. All rights reserved.
//

#import <libxml/xmlstring.h>
#import <RSParser/RSRSSParser.h>
#import <RSParser/RSSAXParser.h>
#import <RSParser/RSParsedFeed.h>
#import <RSParser/RSParsedArticle.h>
#import <RSParser/RSParserInternal.h>
#import <RSParser/NSString+RSParser.h>
#import <RSParser/RSDateParser.h>
#import <RSParser/ParserData.h>
#import <RSParser/RSParsedEnclosure.h>
#import <RSParser/RSParsedAuthor.h>

@interface RSRSSParser () <RSSAXParserDelegate>

@property (nonatomic) NSData *feedData;
@property (nonatomic) NSString *urlString;
@property (nonatomic) NSDictionary *currentAttributes;
@property (nonatomic) RSSAXParser *parser;
@property (nonatomic) NSMutableArray *articles;
@property (nonatomic) BOOL parsingArticle;
@property (nonatomic, readonly) RSParsedArticle *currentArticle;
@property (nonatomic) BOOL parsingChannelImage;
@property (nonatomic, readonly) NSDate *currentDate;
@property (nonatomic) BOOL endRSSFound;
@property (nonatomic) NSString *link;
@property (nonatomic) NSString *title;
@property (nonatomic) NSDate *dateParsed;
@property (nonatomic) BOOL isRDF;

@end


@implementation RSRSSParser

#pragma mark - Class Methods

+ (RSParsedFeed *)parseFeedWithData:(ParserData *)parserData {

	RSRSSParser *parser = [[[self class] alloc] initWithParserData:parserData];
	return [parser parseFeed];
}

#pragma mark - Init

- (instancetype)initWithParserData:(ParserData *)parserData {
	
	self = [super init];
	if (!self) {
		return nil;
	}
	
	_feedData = parserData.data;
	_urlString = parserData.url;
	_parser = [[RSSAXParser alloc] initWithDelegate:self];
	_articles = [NSMutableArray new];

	return self;
}


#pragma mark - API

- (RSParsedFeed *)parseFeed {
	
	[self parse];

	RSParsedFeed *parsedFeed = [[RSParsedFeed alloc] initWithURLString:self.urlString title:self.title link:self.link articles:self.articles];

	return parsedFeed;
}


#pragma mark - Constants

static NSString *kIsPermaLinkKey = @"isPermaLink";
static NSString *kURLKey = @"url";
static NSString *kLengthKey = @"length";
static NSString *kTypeKey = @"type";
static NSString *kFalseValue = @"false";
static NSString *kTrueValue = @"true";
static NSString *kContentEncodedKey = @"content:encoded";
static NSString *kDCDateKey = @"dc:date";
static NSString *kDCCreatorKey = @"dc:creator";
static NSString *kRDFAboutKey = @"rdf:about";

static const char *kItem = "item";
static const NSInteger kItemLength = 5;

static const char *kImage = "image";
static const NSInteger kImageLength = 6;

static const char *kLink = "link";
static const NSInteger kLinkLength = 5;

static const char *kTitle = "title";
static const NSInteger kTitleLength = 6;

static const char *kDC = "dc";
static const NSInteger kDCLength = 3;

static const char *kCreator = "creator";
static const NSInteger kCreatorLength = 8;

static const char *kDate = "date";
static const NSInteger kDateLength = 5;

static const char *kContent = "content";
static const NSInteger kContentLength = 8;

static const char *kEncoded = "encoded";
static const NSInteger kEncodedLength = 8;

static const char *kGuid = "guid";
static const NSInteger kGuidLength = 5;

static const char *kPubDate = "pubDate";
static const NSInteger kPubDateLength = 8;

static const char *kAuthor = "author";
static const NSInteger kAuthorLength = 7;

static const char *kDescription = "description";
static const NSInteger kDescriptionLength = 12;

static const char *kRSS = "rss";
static const NSInteger kRSSLength = 4;

static const char *kURL = "url";
static const NSInteger kURLLength = 4;

static const char *kLength = "length";
static const NSInteger kLengthLength = 7;

static const char *kType = "type";
static const NSInteger kTypeLength = 5;

static const char *kIsPermaLink = "isPermaLink";
static const NSInteger kIsPermaLinkLength = 12;

static const char *kRDF = "rdf";
static const NSInteger kRDFlength = 4;

static const char *kAbout = "about";
static const NSInteger kAboutLength = 6;

static const char *kFalse = "false";
static const NSInteger kFalseLength = 6;

static const char *kTrue = "true";
static const NSInteger kTrueLength = 5;

static const char *kUppercaseRDF = "RDF";
static const NSInteger kUppercaseRDFLength = 4;

static const char *kEnclosure = "enclosure";
static const NSInteger kEnclosureLength = 10;

#pragma mark - Parsing

- (void)parse {

	self.dateParsed = [NSDate date];

	@autoreleasepool {
		[self.parser parseData:self.feedData];
		[self.parser finishParsing];
	}
}


- (void)addArticle {

	RSParsedArticle *article = [[RSParsedArticle alloc] initWithFeedURL:self.urlString];
	article.dateParsed = self.dateParsed;
	
	[self.articles addObject:article];
}


- (RSParsedArticle *)currentArticle {

	return self.articles.lastObject;
}


- (void)addFeedElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix {

	if (prefix != NULL) {
		return;
	}

	if (RSSAXEqualTags(localName, kLink, kLinkLength)) {
		if (!self.link) {
			self.link = self.parser.currentStringWithTrimmedWhitespace;
		}
	}

	else if (RSSAXEqualTags(localName, kTitle, kTitleLength)) {
		self.title = self.parser.currentStringWithTrimmedWhitespace;
	}
}

- (void)addAuthorWithString:(NSString *)authorString {

	if (RSParserStringIsEmpty(authorString)) {
		return;
	}
	
	RSParsedAuthor *author = [RSParsedAuthor authorWithSingleString:self.parser.currentStringWithTrimmedWhitespace];
	[self.currentArticle addAuthor:author];
}

- (void)addDCElement:(const xmlChar *)localName {

	if (RSSAXEqualTags(localName, kCreator, kCreatorLength)) {
		[self addAuthorWithString:self.parser.currentStringWithTrimmedWhitespace];
	}
	else if (RSSAXEqualTags(localName, kDate, kDateLength)) {
		self.currentArticle.datePublished = self.currentDate;
	}
}


- (void)addGuid {

	self.currentArticle.guid = self.parser.currentStringWithTrimmedWhitespace;

	NSString *isPermaLinkValue = [self.currentAttributes rsparser_objectForCaseInsensitiveKey:@"ispermalink"];
	if (!isPermaLinkValue || ![isPermaLinkValue isEqualToString:@"false"]) {
		self.currentArticle.permalink = [self urlString:self.currentArticle.guid];
	}
}

- (void)addEnclosure {

	NSDictionary *attributes = self.currentAttributes;
	NSString *url = attributes[kURLKey];
	if (!url || url.length < 1) {
		return;
	}

	RSParsedEnclosure *enclosure = [[RSParsedEnclosure alloc] init];
	enclosure.url = url;
	enclosure.length = [attributes[kLengthKey] integerValue];
	enclosure.mimeType = attributes[kTypeKey];

	[self.currentArticle addEnclosure:enclosure];
}

- (NSString *)urlString:(NSString *)s {

	/*Resolve against home page URL (if available) or feed URL.*/

	if ([[s lowercaseString] hasPrefix:@"http"]) {
		return s;
	}

	if (!self.link) {
		//TODO: get feed URL and use that to resolve URL.*/
		return s;
	}

	NSURL *baseURL = [NSURL URLWithString:self.link];
	if (!baseURL) {
		return s;
	}

	NSURL *resolvedURL = [NSURL URLWithString:s relativeToURL:baseURL];
	if (resolvedURL.absoluteString) {
		return resolvedURL.absoluteString;
	}

	return s;
}


- (NSString *)currentStringWithHTMLEntitiesDecoded {

	return [self.parser.currentStringWithTrimmedWhitespace rsparser_stringByDecodingHTMLEntities];
}

- (void)addArticleElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix {

	if (RSSAXEqualTags(prefix, kDC, kDCLength)) {

		[self addDCElement:localName];
		return;
	}

	if (RSSAXEqualTags(prefix, kContent, kContentLength) && RSSAXEqualTags(localName, kEncoded, kEncodedLength)) {

		self.currentArticle.body = [self currentStringWithHTMLEntitiesDecoded];
		return;
	}

	if (prefix != NULL) {
		return;
	}

	if (RSSAXEqualTags(localName, kGuid, kGuidLength)) {
		[self addGuid];
	}
	else if (RSSAXEqualTags(localName, kPubDate, kPubDateLength)) {
		self.currentArticle.datePublished = self.currentDate;
	}
	else if (RSSAXEqualTags(localName, kAuthor, kAuthorLength)) {
		[self addAuthorWithString:self.parser.currentStringWithTrimmedWhitespace];
	}
	else if (RSSAXEqualTags(localName, kLink, kLinkLength)) {
		self.currentArticle.link = [self urlString:self.parser.currentStringWithTrimmedWhitespace];
	}
	else if (RSSAXEqualTags(localName, kDescription, kDescriptionLength)) {

		if (!self.currentArticle.body) {
			self.currentArticle.body = [self currentStringWithHTMLEntitiesDecoded];
		}
	}
	else if (RSSAXEqualTags(localName, kTitle, kTitleLength)) {
		self.currentArticle.title = [self currentStringWithHTMLEntitiesDecoded];
	}
	else if (RSSAXEqualTags(localName, kEnclosure, kEnclosureLength)) {
		[self addEnclosure];
	}
}


- (NSDate *)currentDate {

	return RSDateWithBytes(self.parser.currentCharacters.bytes, self.parser.currentCharacters.length);
}


#pragma mark - RSSAXParserDelegate

- (void)saxParser:(RSSAXParser *)SAXParser XMLStartElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix uri:(const xmlChar *)uri numberOfNamespaces:(NSInteger)numberOfNamespaces namespaces:(const xmlChar **)namespaces numberOfAttributes:(NSInteger)numberOfAttributes numberDefaulted:(int)numberDefaulted attributes:(const xmlChar **)attributes {

	if (self.endRSSFound) {
		return;
	}

	if (RSSAXEqualTags(localName, kUppercaseRDF, kUppercaseRDFLength)) {
		self.isRDF = YES;
		return;
	}

	NSDictionary *xmlAttributes = nil;
	if ((self.isRDF && RSSAXEqualTags(localName, kItem, kItemLength)) || RSSAXEqualTags(localName, kGuid, kGuidLength) || RSSAXEqualTags(localName, kEnclosure, kEnclosureLength)) {
		xmlAttributes = [self.parser attributesDictionary:attributes numberOfAttributes:numberOfAttributes];
	}
	if (self.currentAttributes != xmlAttributes) {
		self.currentAttributes = xmlAttributes;
	}

	if (!prefix && RSSAXEqualTags(localName, kItem, kItemLength)) {

		[self addArticle];
		self.parsingArticle = YES;

		if (self.isRDF && xmlAttributes && xmlAttributes[kRDFAboutKey]) { /*RSS 1.0 guid*/
			self.currentArticle.guid = xmlAttributes[kRDFAboutKey];
			self.currentArticle.permalink = self.currentArticle.guid;
		}
	}

	else if (!prefix && RSSAXEqualTags(localName, kImage, kImageLength)) {
		self.parsingChannelImage = YES;
	}

	if (!self.parsingChannelImage) {
		[self.parser beginStoringCharacters];
	}
}


- (void)saxParser:(RSSAXParser *)SAXParser XMLEndElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix uri:(const xmlChar *)uri {

	if (self.endRSSFound) {
		return;
	}

	if (self.isRDF && RSSAXEqualTags(localName, kUppercaseRDF, kUppercaseRDFLength)) {
		self.endRSSFound = YES;
	}

	else if (RSSAXEqualTags(localName, kRSS, kRSSLength)) {
		self.endRSSFound = YES;
	}

	else if (RSSAXEqualTags(localName, kImage, kImageLength)) {
		self.parsingChannelImage = NO;
	}

	else if (RSSAXEqualTags(localName, kItem, kItemLength)) {
		self.parsingArticle = NO;
	}

	else if (self.parsingArticle) {
		[self addArticleElement:localName prefix:prefix];
	}

	else if (!self.parsingChannelImage) {
		[self addFeedElement:localName prefix:prefix];
	}
}


- (NSString *)saxParser:(RSSAXParser *)SAXParser internedStringForName:(const xmlChar *)name prefix:(const xmlChar *)prefix {

	if (RSSAXEqualTags(prefix, kRDF, kRDFlength)) {

		if (RSSAXEqualTags(name, kAbout, kAboutLength)) {
			return kRDFAboutKey;
		}

		return nil;
	}

	if (prefix) {
		return nil;
	}

	if (RSSAXEqualTags(name, kIsPermaLink, kIsPermaLinkLength)) {
		return kIsPermaLinkKey;
	}

	if (RSSAXEqualTags(name, kURL, kURLLength)) {
		return kURLKey;
	}

	if (RSSAXEqualTags(name, kLength, kLengthLength)) {
		return kLengthKey;
	}

	if (RSSAXEqualTags(name, kType, kTypeLength)) {
		return kTypeKey;
	}

	return nil;
}


static BOOL equalBytes(const void *bytes1, const void *bytes2, NSUInteger length) {

	return memcmp(bytes1, bytes2, length) == 0;
}


- (NSString *)saxParser:(RSSAXParser *)SAXParser internedStringForValue:(const void *)bytes length:(NSUInteger)length {

	static const NSUInteger falseLength = kFalseLength - 1;
	static const NSUInteger trueLength = kTrueLength - 1;

	if (length == falseLength && equalBytes(bytes, kFalse, falseLength)) {
		return kFalseValue;
	}

	if (length == trueLength && equalBytes(bytes, kTrue, trueLength)) {
		return kTrueValue;
	}

	return nil;
}


@end
