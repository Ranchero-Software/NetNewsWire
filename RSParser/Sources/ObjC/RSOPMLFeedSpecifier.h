//
//  RSOPMLFeedSpecifier.h
//  RSParser
//
//  Created by Brent Simmons on 2/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface RSOPMLFeedSpecifier : NSObject

- (instancetype)initWithTitle:(NSString * _Nullable)title feedDescription:(NSString * _Nullable)feedDescription homePageURL:(NSString * _Nullable)homePageURL feedURL:(NSString *)feedURL;

@property (nonatomic, nullable, readonly) NSString *title;
@property (nonatomic, nullable, readonly) NSString *feedDescription;
@property (nonatomic, nullable, readonly) NSString *homePageURL;
@property (nonatomic, readonly) NSString *feedURL;

@end

NS_ASSUME_NONNULL_END
