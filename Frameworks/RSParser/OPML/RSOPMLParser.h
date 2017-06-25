//
//  RSOPMLParser.h
//  RSParser
//
//  Created by Brent Simmons on 7/12/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


@class ParserData;
@class RSOPMLDocument;

@interface RSOPMLParser: NSObject

+ (RSOPMLDocument *)parseOPMLWithParserData:(ParserData *)parserData error:(NSError **)error;

@end

