//
//  RSSAXHTMLParser.h
//  RSXML
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

@class RSSAXHTMLParser;

@protocol RSSAXHTMLParserDelegate <NSObject>

@optional

- (void)saxParser:(RSSAXHTMLParser *)SAXParser XMLStartElement:(const unsigned char *)localName attributes:(const unsigned char **)attributes;

- (void)saxParser:(RSSAXHTMLParser *)SAXParser XMLEndElement:(const unsigned char *)localName;

- (void)saxParser:(RSSAXHTMLParser *)SAXParser XMLCharactersFound:(const unsigned char *)characters length:(NSUInteger)length;

- (void)saxParserDidReachEndOfDocument:(RSSAXHTMLParser *)SAXParser; // If canceled, may not get called (but might).

@end


@interface RSSAXHTMLParser : NSObject


- (instancetype)initWithDelegate:(id<RSSAXHTMLParserDelegate>)delegate;

- (void)parseData:(NSData *)data;
- (void)parseBytes:(const void *)bytes numberOfBytes:(NSUInteger)numberOfBytes;
- (void)finishParsing;
- (void)cancel;

@property (nonatomic, strong, readonly) NSData *currentCharacters; // nil if not storing characters. UTF-8 encoded.
@property (nonatomic, strong, readonly) NSString *currentString; // Convenience to get string version of currentCharacters.
@property (nonatomic, strong, readonly) NSString *currentStringWithTrimmedWhitespace;

- (void)beginStoringCharacters; // Delegate can call from XMLStartElement. Characters will be available in XMLEndElement as currentCharacters property. Storing characters is stopped after each XMLEndElement.

// Delegate can call from within XMLStartElement.

- (NSDictionary *)attributesDictionary:(const unsigned char **)attributes;


@end
