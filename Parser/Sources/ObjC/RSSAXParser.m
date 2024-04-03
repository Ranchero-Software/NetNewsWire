//
//  RSSAXParser.m
//  RSParser
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

#import "RSSAXParser.h"
#import "RSParserInternal.h"

#import <libxml/parser.h>
#import <libxml/tree.h>
#import <libxml/xmlstring.h>



@interface RSSAXParser ()

@property (nonatomic, weak) id<RSSAXParserDelegate> delegate;
@property (nonatomic, assign) xmlParserCtxtPtr context;
@property (nonatomic, assign) BOOL storingCharacters;
@property (nonatomic) NSMutableData *characters;
@property (nonatomic) BOOL delegateRespondsToInternedStringMethod;
@property (nonatomic) BOOL delegateRespondsToInternedStringForValueMethod;
@property (nonatomic) BOOL delegateRespondsToStartElementMethod;
@property (nonatomic) BOOL delegateRespondsToEndElementMethod;
@property (nonatomic) BOOL delegateRespondsToCharactersFoundMethod;
@property (nonatomic) BOOL delegateRespondsToEndOfDocumentMethod;

@end


@implementation RSSAXParser

+ (void)initialize {

	RSSAXInitLibXMLParser();
}


#pragma mark - Init

- (instancetype)initWithDelegate:(id<RSSAXParserDelegate>)delegate {

	self = [super init];
	if (self == nil)
		return nil;

	_delegate = delegate;

	if ([_delegate respondsToSelector:@selector(saxParser:internedStringForName:prefix:)]) {
		_delegateRespondsToInternedStringMethod = YES;
	}
	if ([_delegate respondsToSelector:@selector(saxParser:internedStringForValue:length:)]) {
		_delegateRespondsToInternedStringForValueMethod = YES;
	}
	if ([_delegate respondsToSelector:@selector(saxParser:XMLStartElement:prefix:uri:numberOfNamespaces:namespaces:numberOfAttributes:numberDefaulted:attributes:)]) {
		_delegateRespondsToStartElementMethod = YES;
	}
	if ([_delegate respondsToSelector:@selector(saxParser:XMLEndElement:prefix:uri:)]) {
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
		xmlFreeParserCtxt(_context);
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

		self.context = xmlCreatePushParserCtxt(&saxHandlerStruct, (__bridge void *)self, nil, 0, nil);
		xmlCtxtUseOptions(self.context, XML_PARSE_RECOVER | XML_PARSE_NOENT);
	}

	@autoreleasepool {
		xmlParseChunk(self.context, (const char *)bytes, (int)numberOfBytes, 0);
	}
}


- (void)finishParsing {

	NSAssert(self.context != nil, nil);
	if (self.context == nil)
		return;

	@autoreleasepool {
		xmlParseChunk(self.context, nil, 0, 1);
		xmlFreeParserCtxt(self.context);
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

- (NSDictionary *)attributesDictionary:(const xmlChar **)attributes numberOfAttributes:(NSInteger)numberOfAttributes {

	if (numberOfAttributes < 1 || !attributes) {
		return nil;
	}

	NSMutableDictionary *d = [NSMutableDictionary new];

	@autoreleasepool {
		NSInteger i = 0, j = 0;
		for (i = 0, j = 0; i < numberOfAttributes; i++, j+=5) {

			NSUInteger lenValue = (NSUInteger)(attributes[j + 4] - attributes[j + 3]);
			NSString *value = nil;

			if (self.delegateRespondsToInternedStringForValueMethod) {
				value = [self.delegate saxParser:self internedStringForValue:(const void *)attributes[j + 3] length:lenValue];
			}
			if (!value) {
				value = [[NSString alloc] initWithBytes:(const void *)attributes[j + 3] length:lenValue encoding:NSUTF8StringEncoding];
			}

			NSString *attributeName = nil;

			if (self.delegateRespondsToInternedStringMethod) {
				attributeName = [self.delegate saxParser:self internedStringForName:(const xmlChar *)attributes[j] prefix:(const xmlChar *)attributes[j + 1]];
			}

			if (!attributeName) {
				attributeName = [NSString stringWithUTF8String:(const char *)attributes[j]];
				if (attributes[j + 1]) {
					NSString *attributePrefix = [NSString stringWithUTF8String:(const char *)attributes[j + 1]];
					attributeName = [NSString stringWithFormat:@"%@:%@", attributePrefix, attributeName];
				}
			}

			if (value && attributeName) {
				d[attributeName] = value;
			}
		}
	}

	return d;
}


#pragma mark - Equal Tags

BOOL RSSAXEqualTags(const xmlChar *localName, const char *tag, NSInteger tagLength) {

	if (!localName) {
		return NO;
	}
	return !strncmp((const char *)localName, tag, (size_t)tagLength);
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


- (void)xmlStartElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix uri:(const xmlChar *)uri numberOfNamespaces:(int)numberOfNamespaces namespaces:(const xmlChar **)namespaces numberOfAttributes:(int)numberOfAttributes numberDefaulted:(int)numberDefaulted attributes:(const xmlChar **)attributes {

	@autoreleasepool {
		if (self.delegateRespondsToStartElementMethod) {

			[self.delegate saxParser:self XMLStartElement:localName prefix:prefix uri:uri numberOfNamespaces:numberOfNamespaces namespaces:namespaces numberOfAttributes:numberOfAttributes numberDefaulted:numberDefaulted attributes:attributes];
		}
	}
}


- (void)xmlEndElement:(const xmlChar *)localName prefix:(const xmlChar *)prefix uri:(const xmlChar *)uri {

	@autoreleasepool {
		if (self.delegateRespondsToEndElementMethod) {
			[self.delegate saxParser:self XMLEndElement:localName prefix:prefix uri:uri];
		}

		[self endStoringCharacters];
	}
}


@end


static void startElementSAX(void *context, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI, int nb_namespaces, const xmlChar **namespaces, int nb_attributes, int nb_defaulted, const xmlChar **attributes) {

	[(__bridge RSSAXParser *)context xmlStartElement:localname prefix:prefix uri:URI numberOfNamespaces:nb_namespaces namespaces:namespaces numberOfAttributes:nb_attributes numberDefaulted:nb_defaulted attributes:attributes];
}


static void	endElementSAX(void *context, const xmlChar *localname, const xmlChar *prefix, const xmlChar *URI) {
	[(__bridge RSSAXParser *)context xmlEndElement:localname prefix:prefix uri:URI];
}


static void	charactersFoundSAX(void *context, const xmlChar *ch, int len) {
	[(__bridge RSSAXParser *)context xmlCharactersFound:ch length:(NSUInteger)len];
}


static void endDocumentSAX(void *context) {
	[(__bridge RSSAXParser *)context xmlEndDocument];
}


static xmlSAXHandler saxHandlerStruct = {
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
	nil,					/* startElement*/
	nil,					/* endElement */
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
	startElementSAX,		/* startElementNs */
	endElementSAX,			/* endElementNs */
	nil						/* serror */
};


void RSSAXInitLibXMLParser(void) {

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		xmlInitParser();
	});
}

