//
//  RSHTMLMetadataParser.h
//  RSXML
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


@class RSHTMLMetadata;
@class RSXMLData;

NS_ASSUME_NONNULL_BEGIN

@interface RSHTMLMetadataParser : NSObject

+ (RSHTMLMetadata *)HTMLMetadataWithXMLData:(RSXMLData *)xmlData;

- (instancetype)initWithXMLData:(RSXMLData *)xmlData;

@property (nonatomic, readonly) RSHTMLMetadata *metadata;


@end

NS_ASSUME_NONNULL_END
