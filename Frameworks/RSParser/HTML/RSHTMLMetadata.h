//
//  RSHTMLMetadata.h
//  RSParser
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

@class RSHTMLMetadataFeedLink;
@class RSHTMLMetadataAppleTouchIcon;


@interface RSHTMLMetadata : NSObject

- (instancetype)initWithURLString:(NSString *)urlString dictionaries:(NSArray <NSDictionary *> *)dictionaries;

@property (nonatomic, readonly) NSString *baseURLString;
@property (nonatomic, readonly) NSArray <NSDictionary *> *dictionaries;

@property (nonatomic, readonly) NSString *faviconLink;
@property (nonatomic, readonly) NSArray <RSHTMLMetadataAppleTouchIcon *> *appleTouchIcons;
@property (nonatomic, readonly) NSArray <RSHTMLMetadataFeedLink *> *feedLinks;

@end


@interface RSHTMLMetadataAppleTouchIcon : NSObject

@property (nonatomic, readonly) NSString *rel;
@property (nonatomic, readonly) NSString *sizes;
@property (nonatomic, readonly) NSString *urlString; // Absolute.

@end


@interface RSHTMLMetadataFeedLink : NSObject

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) NSString *urlString; // Absolute.

@end

