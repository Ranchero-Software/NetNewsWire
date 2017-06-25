//
//  RSHTMLMetadataParser.h
//  RSParser
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


@class RSHTMLMetadata;
@class ParserData;

NS_ASSUME_NONNULL_BEGIN

@interface RSHTMLMetadataParser : NSObject

+ (RSHTMLMetadata *)HTMLMetadataWithParserData:(ParserData *)parserData;


@end

NS_ASSUME_NONNULL_END
