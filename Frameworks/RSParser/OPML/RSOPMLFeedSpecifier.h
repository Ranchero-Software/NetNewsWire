//
//  RSOPMLFeedSpecifier.h
//  RSParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;


@interface RSOPMLFeedSpecifier : NSObject


- (instancetype)initWithTitle:(NSString *)title feedDescription:(NSString *)feedDescription homePageURL:(NSString *)homePageURL feedURL:(NSString *)feedURL;

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *feedDescription;
@property (nonatomic, readonly) NSString *homePageURL;
@property (nonatomic, readonly) NSString *feedURL;


@end
