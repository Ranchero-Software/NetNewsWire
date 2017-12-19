//
//  RSParsedArticle.h
//  RSParser
//
//  Created by Brent Simmons on 12/6/14.
//  Copyright (c) 2014 Ranchero Software LLC. All rights reserved.
//

@import Foundation;

@class RSParsedEnclosure;

@interface RSParsedArticle : NSObject

- (nonnull instancetype)initWithFeedURL:(NSString * _Nonnull)feedURL;

@property (nonatomic, readonly, nonnull) NSString *feedURL;
@property (nonatomic, nonnull) NSString *articleID; //Calculated. Don't get until other properties have been set.

@property (nonatomic, nullable) NSString *guid;
@property (nonatomic, nullable) NSString *title;
@property (nonatomic, nullable) NSString *body;
@property (nonatomic, nullable) NSString *link;
@property (nonatomic, nullable) NSString *permalink;
@property (nonatomic, nullable) NSString *author;
@property (nonatomic, nullable) NSSet<RSParsedEnclosure *> *enclosures;
@property (nonatomic, nullable) NSDate *datePublished;
@property (nonatomic, nullable) NSDate *dateModified;
@property (nonatomic, nonnull) NSDate *dateParsed;

- (void)addEnclosure:(RSParsedEnclosure *_Nonnull)enclosure;

- (void)calculateArticleID; // Optimization. Call after all properties have been set. Call on a background thread.

@end

