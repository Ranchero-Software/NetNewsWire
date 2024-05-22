//
//  RSSAXHTMLParser.m
//  RSParser
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RSSAXHTMLParser.h"
#import "RSSAXParser.h"
#import "RSParserInternal.h"

#import <libxml/tree.h>
#import <libxml/xmlstring.h>
#import <libxml/HTMLparser.h>



@interface RSSAXHTMLParser ()

@property (nonatomic) id<RSSAXHTMLParserDelegate> delegate;
@property (nonatomic, assign) htmlParserCtxtPtr context;
@property (nonatomic, assign) BOOL storingCharacters;
@property (nonatomic) NSMutableData *characters;
@property (nonatomic) BOOL delegateRespondsToStartElementMethod;
@property (nonatomic) BOOL delegateRespondsToEndElementMethod;
@property (nonatomic) BOOL delegateRespondsToCharactersFoundMethod;
@property (nonatomic) BOOL delegateRespondsToEndOfDocumentMethod;

@end


@implementation RSSAXHTMLParser


+ (void)initialize {

	RSSAXInitLibXMLParser();
}


#pragma mark - Init

- (instancetype)initWithDelegate:(id<RSSAXHTMLParserDelegate>)delegate {

	self = [super init];
	if (self == nil)
		return nil;

	_delegate = delegate;

	if ([_delegate respondsToSelector:@selector(saxParser:XMLStartElement:attributes:)]) {
		_delegateRespondsToStartElementMethod = YES;
	}
	if ([_delegate respondsToSelector:@selector(saxParser:XMLEndElement:)]) {
		_delegateRespondsToEndElementMethod = YES;
	}
	if ([_delegate respondsToSelector:@selector(saxParser:XMLCharactersFound:length:)]) {
		_delegateRespondsToCharactersFoundMethod = YES;
	}
	if ([_delegate respondsToSelector:@selector(saxParserDidReachEndOfDocument:)]) {
		_delegateRespondsToEndOfDocumentMethod = YES;
	}

	return self;
}


#pragma mark - Dealloc

- (void)dealloc {
	
	if (_context != nil) {
		htmlFreeParserCtxt(_context);
		_context = nil;
	}
	_delegate = nil;
}


#pragma mark - API

static xmlSAXHandler saxHandlerStruct;

- (void)parseData:(NSData *)data {

	[self parseBytes:data.bytes numberOfBytes:data.length];
}


- (void)parseBytes:(const void *)bytes numberOfBytes:(NSUInteger)numberOfBytes {

	if (self.context == nil) {

		xmlCharEncoding characterEncoding = xmlDetectCharEncoding(bytes, (int)numberOfBytes);
		self.context = htmlCreatePushParserCtxt(&saxHandlerStruct, (__bridge void *)self, nil, 0, nil, characterEncoding);
		htmlCtxtUseOptions(self.context, XML_PARSE_RECOVER | XML_PARSE_NONET | HTML_PARSE_COMPACT);
	}

	@autoreleasepool {
		htmlParseChunk(self.context, (const char *)bytes, (int)numberOfBytes, 0);
	}
}


- (void)finishParsing {

	NSAssert(self.context != nil, nil);
	if (self.context == nil)
		return;

	@autoreleasepool {
		htmlParseChunk(self.context, nil, 0, 1);
		htmlFreeParserCtxt(self.context);
		self.context = nil;
		self.characters = nil;
	}
}


- (void)cancel {

	@autoreleasepool {
		xmlStopParser(self.context);
	}
}



- (void)beginStoringCharacters {
	self.storingCharacters = YES;
	self.characters = [NSMutableData new];
}


- (void)endStoringCharacters {
	self.storingCharacters = NO;
	self.characters = nil;
}


- (NSData *)currentCharacters {

	if (!self.storingCharacters) {
		return nil;
	}

	return self.characters;
}


- (NSString *)currentString {

	NSData *d = self.currentCharacters;
	if (RSParserObjectIsEmpty(d)) {
		return nil;
	}

	return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
}


- (NSString *)currentStringWithTrimmedWhitespace {
	
	return [self.currentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}


#pragma mark - Attributes Dictionary

- (NSDictionary *)attributesDictionary:(const xmlChar **)attributes {

	if (!attributes) {
		return nil;
	}

	NSMutableDictionary *d = [NSMutableDictionary new];

	NSInteger ix = 0;
	NSString *currentKey = nil;
	while (true) {

		const xmlChar *oneAttribute = attributes[ix];
		ix++;

		if (!currentKey && !oneAttribute) {
			break;
		}

		if (!currentKey) {
			currentKey = [NSString stringWithUTF8String:(const char *)oneAttribute];
		}
		else {
			NSString *value = nil;
			if (oneAttribute) {
				value = [NSString stringWithUTF8String:(const char *)oneAttribute];
			}

			d[currentKey] = value ? value : @"";
			currentKey = nil;
		}
	}

	return [d copy];
}


#pragma mark - Callbacks

- (void)xmlEndDocument {

	@autoreleasepool {
		if (self.delegateRespondsToEndOfDocumentMethod) {
			[self.delegate saxParserDidReachEndOfDocument:self];
		}

		[self endStoringCharacters];
	}
}


- (void)xmlCharactersFound:(const xmlChar *)ch length:(NSUInteger)length {

	if (length < 1) {
		return;
	}
	
	@autoreleasepool {
		if (self.storingCharacters) {
			[self.characters appendBytes:(const void *)ch length:length];
		}

		if (self.delegateRespondsToCharactersFoundMethod) {
			[self.delegate saxParser:self XMLCharactersFound:ch length:length];
		}
	}
}


- (void)xmlStartElement:(const xmlChar *)localName attributes:(const xmlChar **)attributes {

	@autoreleasepool {
		if (self.delegateRespondsToStartElementMethod) {

			[self.delegate saxParser:self XMLStartElement:localName attributes:attributes];
		}
	}
}


- (void)xmlEndElement:(const xmlChar *)localName {

	@autoreleasepool {
		if (self.delegateRespondsToEndElementMethod) {
			[self.delegate saxParser:self XMLEndElement:localName];
		}

		[self endStoringCharacters];
	}
}


@end


static void startElementSAX(void *context, const xmlChar *localname, const xmlChar **attributes) {

	[(__bridge RSSAXHTMLParser *)context xmlStartElement:localname attributes:attributes];
}


static void	endElementSAX(void *context, const xmlChar *localname) {
	[(__bridge RSSAXHTMLParser *)context xmlEndElement:localname];
}


static void	charactersFoundSAX(void *context, const xmlChar *ch, int len) {
	[(__bridge RSSAXHTMLParser *)context xmlCharactersFound:ch length:(NSUInteger)len];
}


static void endDocumentSAX(void *context) {
	[(__bridge RSSAXHTMLParser *)context xmlEndDocument];
}


static htmlSAXHandler saxHandlerStruct = {
	nil,					/* internalSubset */
	nil,					/* isStandalone   */
	nil,					/* hasInternalSubset */
	nil,					/* hasExternalSubset */
	nil,					/* resolveEntity */
	nil,					/* getEntity */
	nil,					/* entityDecl */
	nil,					/* notationDecl */
	nil,					/* attributeDecl */
	nil,					/* elementDecl */
	nil,					/* unparsedEntityDecl */
	nil,					/* setDocumentLocator */
	nil,					/* startDocument */
	endDocumentSAX,			/* endDocument */
	startElementSAX,		/* startElement*/
	endElementSAX,			/* endElement */
	nil,					/* reference */
	charactersFoundSAX,		/* characters */
	nil,					/* ignorableWhitespace */
	nil,					/* processingInstruction */
	nil,					/* comment */
	nil,					/* warning */
	nil,					/* error */
	nil,					/* fatalError //: unused error() get all the errors */
	nil,					/* getParameterEntity */
	nil,					/* cdataBlock */
	nil,					/* externalSubset */
	XML_SAX2_MAGIC,
	nil,
	nil,					/* startElementNs */
	nil,					/* endElementNs */
	nil						/* serror */
};

