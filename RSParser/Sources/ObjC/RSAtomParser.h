//
//  RSAtomParser.h
//  RSParser
//
//  Created by Brent Simmons on 1/15/15.
//  Copyright (c) 2015 Ranchero Software LLC. All rights reserved.
//

@import Foundation;

@class ParserData;
@class RSParsedFeed;

@interface RSAtomParser : NSObject

+ (RSParsedFeed *)parseFeedWithData:(ParserData *)parserData;

@end
