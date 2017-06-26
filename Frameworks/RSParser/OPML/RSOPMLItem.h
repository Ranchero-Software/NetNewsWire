//
//  RSOPMLItem.h
//  RSParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

@class RSOPMLFeedSpecifier;


@interface RSOPMLItem : NSObject

@property (nonatomic) NSDictionary *attributes;
@property (nonatomic) NSArray <RSOPMLItem *> *children;

- (void)addChild:(RSOPMLItem *)child;

@property (nonatomic, readonly) RSOPMLFeedSpecifier *OPMLFeedSpecifier; //May be nil.

@property (nonatomic, readonly) NSString *titleFromAttributes; //May be nil.
@property (nonatomic, readonly) BOOL isFolder;

@end
