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

typedef void (^OPMLParserCallback)(RSOPMLDocument *opmlDocument, NSError *error);

// Parses on background thread; calls back on main thread.
void RSParseOPML(ParserData *parserData, OPMLParserCallback callback);


@interface RSOPMLParser: NSObject

+ (RSOPMLDocument *)parseOPMLWithParserData:(ParserData *)parserData error:(NSError **)error;

@end

