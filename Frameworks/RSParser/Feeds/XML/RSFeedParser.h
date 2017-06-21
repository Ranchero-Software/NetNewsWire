//
//  RSFeedParser.h
//  RSXML
//
//  Created by Brent Simmons on 1/4/15.
//  Copyright (c) 2015 Ranchero Software LLC. All rights reserved.
//

#import "FeedParser.h"

// If you have a feed and don’t know or care what it is (RSS or Atom),
// then call RSParseFeed or RSParseFeedSync.

@class RSXMLData;
@class RSParsedFeed;

NS_ASSUME_NONNULL_BEGIN

BOOL RSCanParseFeed(RSXMLData *xmlData);


typedef void (^RSParsedFeedBlock)(RSParsedFeed * _Nullable parsedFeed, NSError * _Nullable error);

// callback is called on main queue.
void RSParseFeed(RSXMLData *xmlData, RSParsedFeedBlock callback);
RSParsedFeed * _Nullable RSParseFeedSync(RSXMLData *xmlData, NSError * _Nullable * _Nullable error);

NS_ASSUME_NONNULL_END
