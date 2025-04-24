//
//  NSData+RSParser.h
//  RSParser
//
//  Created by Brent Simmons on 6/24/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


@interface NSData (RSParser)

- (BOOL)isProbablyHTML;
- (BOOL)isProbablyXML;
- (BOOL)isProbablyJSON;

- (BOOL)isProbablyJSONFeed;
- (BOOL)isProbablyRSSInJSON;
- (BOOL)isProbablyRSS;
- (BOOL)isProbablyAtom;

@end



