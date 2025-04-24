//
//  RSAtomParser.m
//  RSParser
//
//  Created by Brent Simmons on 1/15/15.
//  Copyright (c) 2015 Ranchero Software LLC. All rights reserved.
//


#import "RSAtomParser.h"
#import "RSSAXParser.h"
#import "RSParsedFeed.h"
#import "RSParsedArticle.h"
#import "NSString+RSParser.h"
#import "RSDateParser.h"
#import "ParserData.h"
#import "RSParsedEnclosure.h"
#import "RSParsedAuthor.h"

#import <libxml/xmlstring.h>

@interface RSAtomParser () <RSSAXParserDelegate>

@property (nonatomic) NSData *feedData;
@property (nonatomic) NSString *urlString;
@property (nonatomic) BOOL endFeedFound;
@property (nonatomic) BOOL parsingXHTML;
@property (nonatomic) BOOL parsingSource;
@property (nonatomic) BOOL parsingArticle;
@property (nonatomic) BOOL parsingAuthor;
@property (nonatomic) NSMutableArray *attributesStack;
@property (nonatomic, readonly) NSDictionary *currentAttributes;
@property (nonatomic) NSMutableString *xhtmlString;
@property (nonatomic) NSString *link;
@property (nonatomic) NSString *title;
@property (nonatomic) NSMutableArray *articles;
@property (nonatomic) NSDate *dateParsed;
@property (nonatomic) RSSAXParser *parser;
@property (nonatomic, readonly) RSParsedArticle *currentArticle;
@property (nonatomic) RSParsedAuthor *currentAuthor;
@property (nonatomic, readonly) NSDate *currentDate;
@property (nonatomic) NSString *language;

@end


@implementation RSAtomParser

#pragma mark - Class Methods

+ (RSParsedFeed *)parseFeedWithData:(ParserData *)parserData {

	RSAtomParser *parser = [[[self class] alloc] initWithParserData:parserData];
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
	_attributesStack = [NSMutableArray new];
	_articles = [NSMutableArray new];

	return self;
}


#pragma mark - API

- (RSParsedFeed *)parseFeed {

	[self parse];

	RSParsedFeed *parsedFeed = [[RSParsedFeed alloc] initWithURLString:self.urlString title:self.title link:self.link language:self.language articles:self.articles];

	return parsedFeed;
}


#pragma mark - Constants

static NSString *kTypeKey = @"type";
static NSString *kXHTMLType = @"xhtml";
static NSString *kRelKey = @"rel";
static NSString *kAlternateValue = @"alternate";
static NSString *kHrefKey = @"href";
static NSString *kXMLKey = @"xml";
static NSString *kBaseKey = @"base";
static NSString *kLangKey = @"lang";
static NSString *kXMLBaseKey = @"xml:base";
static NSString *kXMLLangKey = @"xml:lang";
static NSString *kTextHTMLValue = @"text/html";
static NSString *kRelatedValue = @"related";
static NSString *kEnclosureValue = @"enclosure";
static NSString *kShortURLValue = @"shorturl";
static NSString *kHTMLValue = @"html";
static NSString *kEnValue = @"en";
static NSString *kTextValue = @"text";
static NSString *kSelfValue = @"self";
static NSString *kLengthKey = @"length";
static NSString *kTitleKey = @"title";

static const char *kID = "id";
static const NSInteger kIDLength = 3;

static const char *kTitle = "title";
static const NSInteger kTitleLength = 6;

static const char *kContent = "content";
static const NSInteger kContentLength = 8;

static const char *kSummary = "summary";
static const NSInteger kSummaryLength = 8;

static const char *kLink = "link";
static const NSInteger kLinkLength = 5;

static const char *kPublished = "published";
static const NSInteger kPublishedLength = 10;

static const char *kIssued = "issued";
static const NSInteger kIssuedLength = 7;

static const char *kUpdated = "updated";
static const NSInteger kUpdatedLength = 8;

static const char *kModified = "modified";
static const NSInteger kModifiedLength = 9;

static const char *kAuthor = "author";
static const NSInteger kAuthorLength = 7;

static const char *kName = "name";
static const NSInteger kNameLength = 5;

static const char *kEmail = "email";
static const NSInteger kEmailLength = 6;

static const char *kURI = "uri";
static const NSInteger kURILength = 4;

static const char *kEntry = "entry";
static const NSInteger kEntryLength = 6;

static const char *kSource = "source";
static const NSInteger kSourceLength = 7;

static const char *kFeed = "feed";
static const NSInteger kFeedLength = 5;

static const char *kType = "type";
static const NSInteger kTypeLength = 5;

static const char *kRel = "rel";
static const NSInteger kRelLength = 4;

static const char *kAlternate = "alternate";
static const NSInteger kAlternateLength = 10;

static const char *kHref = "href";
static const NSInteger kHrefLength = 5;

static const char *kXML = "xml";
static const NSInteger kXMLLength = 4;

static const char *kBase = "base";
static const NSInteger kBaseLength = 5;

static const char *kLang = "lang";
static const NSInteger kLangLength = 5;

static const char *kTextHTML = "text/html";
static const NSInteger kTextHTMLLength = 10;

static const char *kRelated = "related";
static const NSInteger kRelatedLength = 8;

static const char *kShortURL = "shorturl";
static const NSInteger kShortURLLength = 9;

static const char *kHTML = "html";
static const NSInteger kHTMLLength = 5;

static const char *kEn = "en";
static const NSInteger kEnLength = 3;

static const char *kText = "text";
static const NSInteger kTextLength = 5;

static const char *kSelf = "self";
static const NSInteger kSelfLength = 5;

static const char *kEnclosure = "enclosure";
static const NSInteger kEnclosureLength = 10;

static const char *kLength = "length";
static const NSInteger kLengthLength = 7;

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


- (NSDictionary *)currentAttributes {

	return self.attributesStack.lastObject;
}


- (NSDate *)currentDate {

	return RSDateWithBytes(self.parser.currentCharacters.bytes, self.parser.currentCharacters.length);
}


- (void)addFeedLink {

	if (self.link && self.link.length > 0) {
		return;
	}

	NSString *related = self.currentAttributes[kRelKey];
	if (related == kAlternateValue) {
		self.link = self.currentAttributes[kHrefKey];
	}
}


- (void)addFeedTitle {

	if (self.title.length < 1) {
		self.title = [self currentString];
	}
}

- (void)addFeedLanguage {

	if (self.language.length < 0) {
		self.language = self.currentAttributes[kXMLLangKey]
;
	}
}

- (void)addLink {

	NSDictionary *attributes = self.currentAttributes;

	NSString *urlString = attributes[kHrefKey];
	if (urlString.length < 1) {
		return;
	}

	RSParsedArticle *article = self.currentArticle;

	NSString *rel = attributes[kRelKey];
	if (rel.length < 1) {
		rel = kAlternateValue;
	}

	if (rel == kRelatedValue) {
		if (!article.link) {
			article.link = urlString;
		}
	}
	else if (rel == kAlternateValue) {
		if (!article.permalink) {
			article.permalink = urlString;
		}
	}
	else if (rel == kEnclosureValue) {
		RSParsedEnclosure *enclosure = [self enclosureWithURLString:urlString attributes:attributes];
		[article addEnclosure:enclosure];
	}
}

- (RSParsedEnclosure *)enclosureWithURLString:(NSString *)urlString attributes:(NSDictionary *)attributes {

	RSParsedEnclosure *enclosure = [[RSParsedEnclosure alloc] init];
	enclosure.url = urlString;
	enclosure.title = attributes[kTitleKey];
	enclosure.mimeType = attributes[kTypeKey];
	enclosure.length = [attributes[kLengthKey] integerValue];

	return enclosure;
}

- (void)addContent {

	self.currentArticle.body = [self currentString];
}


- (void)addSummary {

	if (!self.currentArticle.body) {
		self.currentArticle.body = [self currentString];
	}
}


- (NSString *)currentString {

	return self.parser.currentStringWithTrimmedWhitespace;
}


- (void)addArticleElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix {

	if (prefix) {
		return;
	}

	if (RSSAXEqualTags(localName, kID, kIDLength)) {
		self.currentArticle.guid = [self currentString];
	}

	else if (RSSAXEqualTags(localName, kTitle, kTitleLength)) {
		self.currentArticle.title = [self currentString];
	}

	else if (RSSAXEqualTags(localName, kContent, kContentLength)) {
		[self addContent];
	}

	else if (RSSAXEqualTags(localName, kSummary, kSummaryLength)) {
		[self addSummary];
	}

	else if (RSSAXEqualTags(localName, kLink, kLinkLength)) {
		[self addLink];
	}

	else if (RSSAXEqualTags(localName, kPublished, kPublishedLength)) {
		self.currentArticle.datePublished = self.currentDate;
	}

	else if (RSSAXEqualTags(localName, kUpdated, kUpdatedLength)) {
		self.currentArticle.dateModified = self.currentDate;
	}

	// Atom 0.3 dates
	else if (RSSAXEqualTags(localName, kIssued, kIssuedLength)) {
		if (!self.currentArticle.datePublished) {
			self.currentArticle.datePublished = self.currentDate;
		}
	}
	else if (RSSAXEqualTags(localName, kModified, kModifiedLength)) {
		if (!self.currentArticle.dateModified) {
			self.currentArticle.dateModified = self.currentDate;
		}
	}
}


- (void)addXHTMLTag:(const xmlChar *)localName {

	if (!localName) {
		return;
	}

	[self.xhtmlString appendString:@"<"];
	[self.xhtmlString appendString:[NSString stringWithUTF8String:(const char *)localName]];

	if (self.currentAttributes.count < 1) {
		[self.xhtmlString appendString:@">"];
		return;
	}

	for (NSString *oneKey in self.currentAttributes) {

		[self.xhtmlString appendString:@" "];

		NSString *oneValue = self.currentAttributes[oneKey];
		[self.xhtmlString appendString:oneKey];

		[self.xhtmlString appendString:@"=\""];

		oneValue = [oneValue stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
		[self.xhtmlString appendString:oneValue];

		[self.xhtmlString appendString:@"\""];
	}

	[self.xhtmlString appendString:@">"];
}


#pragma mark - RSSAXParserDelegate

- (void)saxParser:(RSSAXParser *)SAXParser XMLStartElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix uri:(const xmlChar *)uri numberOfNamespaces:(NSInteger)numberOfNamespaces namespaces:(const xmlChar **)namespaces numberOfAttributes:(NSInteger)numberOfAttributes numberDefaulted:(int)numberDefaulted attributes:(const xmlChar **)attributes {

	if (self.endFeedFound) {
		return;
	}

	NSDictionary *xmlAttributes = [self.parser attributesDictionary:attributes numberOfAttributes:numberOfAttributes];
	if (!xmlAttributes) {
		xmlAttributes = [NSDictionary dictionary];
	}
	[self.attributesStack addObject:xmlAttributes];

	if (self.parsingXHTML) {
		[self addXHTMLTag:localName];
		return;
	}

	if (RSSAXEqualTags(localName, kEntry, kEntryLength)) {
		self.parsingArticle = YES;
		[self addArticle];
		return;
	}

	if (RSSAXEqualTags(localName, kAuthor, kAuthorLength)) {
		self.parsingAuthor = YES;
		self.currentAuthor = [[RSParsedAuthor alloc] init];
		return;
	}

	if (RSSAXEqualTags(localName, kSource, kSourceLength)) {
		self.parsingSource = YES;
		return;
	}

	BOOL isContentTag = RSSAXEqualTags(localName, kContent, kContentLength);
	BOOL isSummaryTag = RSSAXEqualTags(localName, kSummary, kSummaryLength);
	if (self.parsingArticle && (isContentTag || isSummaryTag)) {

		if (isContentTag) {
			self.currentArticle.language = xmlAttributes[kXMLLangKey];
		}

		NSString *contentType = xmlAttributes[kTypeKey];
		if ([contentType isEqualToString:kXHTMLType]) {
			self.parsingXHTML = YES;
			self.xhtmlString = [NSMutableString stringWithString:@""];
			return;
		}
	}

	if (!self.parsingArticle && RSSAXEqualTags(localName, kLink, kLinkLength)) {
		[self addFeedLink];
		return;
	}

	if (RSSAXEqualTags(localName, kFeed, kFeedLength)) {
		[self addFeedLanguage];
	}

	[self.parser beginStoringCharacters];
}


- (void)saxParser:(RSSAXParser *)SAXParser XMLEndElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix uri:(const xmlChar *)uri {

	if (RSSAXEqualTags(localName, kFeed, kFeedLength)) {
		self.endFeedFound = YES;
		return;
	}

	if (self.endFeedFound) {
		return;
	}

	if (self.parsingXHTML) {

		BOOL isContentTag = RSSAXEqualTags(localName, kContent, kContentLength);
		BOOL isSummaryTag = RSSAXEqualTags(localName, kSummary, kSummaryLength);

		if (self.parsingArticle && (isContentTag || isSummaryTag)) {

			if (isContentTag) {
				self.currentArticle.body = [self.xhtmlString copy];
			}

			else if (isSummaryTag) {
				if (self.currentArticle.body.length < 1) {
					self.currentArticle.body = [self.xhtmlString copy];
				}
			}
		}

		if (isContentTag || isSummaryTag) {
			self.parsingXHTML = NO;
		}

		[self.xhtmlString appendString:@"</"];
		[self.xhtmlString appendString:[NSString stringWithUTF8String:(const char *)localName]];
		[self.xhtmlString appendString:@">"];
	}

	else if (self.parsingAuthor) {

		if (RSSAXEqualTags(localName, kAuthor, kAuthorLength)) {
			self.parsingAuthor = NO;
			RSParsedAuthor *author = self.currentAuthor;
			if (author.name || author.emailAddress || author.url) {
				[self.currentArticle addAuthor:author];
			}
			self.currentAuthor = nil;
		}
		else if (RSSAXEqualTags(localName, kName, kNameLength)) {
			self.currentAuthor.name = [self currentString];
		}
		else if (RSSAXEqualTags(localName, kEmail, kEmailLength)) {
			self.currentAuthor.emailAddress = [self currentString];
		}
		else if (RSSAXEqualTags(localName, kURI, kURILength)) {
			self.currentAuthor.url = [self currentString];
		}
	}

	else if (RSSAXEqualTags(localName, kEntry, kEntryLength)) {
		self.parsingArticle = NO;
	}

	else if (self.parsingArticle && !self.parsingSource) {
		[self addArticleElement:localName prefix:prefix];
	}
	
	else if (RSSAXEqualTags(localName, kSource, kSourceLength)) {
		self.parsingSource = NO;
	}

	else if (!self.parsingArticle && !self.parsingSource && RSSAXEqualTags(localName, kTitle, kTitleLength)) {
		[self addFeedTitle];
	}

	[self.attributesStack removeLastObject];
}


- (NSString *)saxParser:(RSSAXParser *)SAXParser internedStringForName:(const xmlChar *)name prefix:(const xmlChar *)prefix {

	if (prefix && RSSAXEqualTags(prefix, kXML, kXMLLength)) {

		if (RSSAXEqualTags(name, kBase, kBaseLength)) {
			return kXMLBaseKey;
		}
		if (RSSAXEqualTags(name, kLang, kLangLength)) {
			return kXMLLangKey;
		}
	}

	if (prefix) {
		return nil;
	}

	if (RSSAXEqualTags(name, kRel, kRelLength)) {
		return kRelKey;
	}

	if (RSSAXEqualTags(name, kType, kTypeLength)) {
		return kTypeKey;
	}

	if (RSSAXEqualTags(name, kHref, kHrefLength)) {
		return kHrefKey;
	}

	if (RSSAXEqualTags(name, kAlternate, kAlternateLength)) {
		return kAlternateValue;
	}

	if (RSSAXEqualTags(name, kLength, kLengthLength)) {
		return kLengthKey;
	}

	if (RSSAXEqualTags(name, kTitle, kTitleLength)) {
		return kTitleKey;
	}

	return nil;
}


static BOOL equalBytes(const void *bytes1, const void *bytes2, NSUInteger length) {

	return memcmp(bytes1, bytes2, length) == 0;
}


- (NSString *)saxParser:(RSSAXParser *)SAXParser internedStringForValue:(const void *)bytes length:(NSUInteger)length {

	static const NSUInteger alternateLength = kAlternateLength - 1;
	static const NSUInteger textHTMLLength = kTextHTMLLength - 1;
	static const NSUInteger relatedLength = kRelatedLength - 1;
	static const NSUInteger shortURLLength = kShortURLLength - 1;
	static const NSUInteger htmlLength = kHTMLLength - 1;
	static const NSUInteger enLength = kEnLength - 1;
	static const NSUInteger textLength = kTextLength - 1;
	static const NSUInteger selfLength = kSelfLength - 1;
	static const NSUInteger enclosureLength = kEnclosureLength - 1;

	if (length == alternateLength && equalBytes(bytes, kAlternate, alternateLength)) {
		return kAlternateValue;
	}

	if (length == enclosureLength && equalBytes(bytes, kEnclosure, enclosureLength)) {
		return kEnclosureValue;
	}

	if (length == textHTMLLength && equalBytes(bytes, kTextHTML, textHTMLLength)) {
		return kTextHTMLValue;
	}

	if (length == relatedLength && equalBytes(bytes, kRelated, relatedLength)) {
		return kRelatedValue;
	}

	if (length == shortURLLength && equalBytes(bytes, kShortURL, shortURLLength)) {
		return kShortURLValue;
	}

	if (length == htmlLength && equalBytes(bytes, kHTML, htmlLength)) {
		return kHTMLValue;
	}

	if (length == enLength && equalBytes(bytes, kEn, enLength)) {
		return kEnValue;
	}

	if (length == textLength && equalBytes(bytes, kText, textLength)) {
		return kTextValue;
	}

	if (length == selfLength && equalBytes(bytes, kSelf, selfLength)) {
		return kSelfValue;
	}

	return nil;
}


- (void)saxParser:(RSSAXParser *)SAXParser XMLCharactersFound:(const unsigned char *)characters length:(NSUInteger)length {

	if (self.parsingXHTML) {
		NSString *s = [[NSString alloc] initWithBytesNoCopy:(void *)characters length:length encoding:NSUTF8StringEncoding freeWhenDone:NO];
		if (s == nil) {
			return;
		}
		// libxml decodes all entities; we need to re-encode certain characters
		// (<, >, and &) when inside XHTML text content.
		[self.xhtmlString appendString:s.rsparser_stringByEncodingRequiredEntities];
	}
}

@end
