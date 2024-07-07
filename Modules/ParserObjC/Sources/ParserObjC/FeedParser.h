//
//  FeedParser.h
//  RSXML
//
//  Created by Brent Simmons on 7/12/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

@class RSParsedFeed;
@class RSXMLData;


@protocol FeedParser <NSObject>

+ (BOOL)canParseFeed:(RSXMLData * _Nonnull)xmlData;

- (nonnull instancetype)initWithXMLData:(RSXMLData * _Nonnull)xmlData;

- (nullable RSParsedFeed *)parseFeed:(NSError * _Nullable * _Nullable)error;


@end
