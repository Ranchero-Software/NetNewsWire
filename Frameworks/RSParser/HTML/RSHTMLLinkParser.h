//
//  RSHTMLLinkParser.h
//  RSParser
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

/*Returns all <a href="some_url">some_text</a> as RSHTMLLink object array.*/

@class ParserData;
@class RSHTMLLink;

@interface RSHTMLLinkParser : NSObject

+ (NSArray <RSHTMLLink *> *)htmlLinksWithParserData:(ParserData *)parserData;

@end


@interface RSHTMLLink : NSObject

// Any of these, even urlString, may be nil, because HTML can be bad.

@property (nonatomic, readonly) NSString *urlString; //absolute
@property (nonatomic, readonly) NSString *text;
@property (nonatomic, readonly) NSString *title; //title attribute inside anchor tag

@end
