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
@class RSHTMLOpenGraphProperties;
@class RSHTMLOpenGraphImage;
@class RSHTMLTag;
@class RSHTMLTwitterProperties;

@interface RSHTMLMetadata : NSObject

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RSHTMLTag *> *)tags;

@property (nonatomic, readonly) NSString *baseURLString;
@property (nonatomic, readonly) NSArray <RSHTMLTag *> *tags;

@property (nonatomic, readonly) NSString *faviconLink;
@property (nonatomic, readonly) NSArray <RSHTMLMetadataAppleTouchIcon *> *appleTouchIcons;
@property (nonatomic, readonly) NSArray <RSHTMLMetadataFeedLink *> *feedLinks;

@property (nonatomic, readonly) RSHTMLOpenGraphProperties *openGraphProperties;
@property (nonatomic, readonly) RSHTMLTwitterProperties *twitterProperties;

@end


@interface RSHTMLMetadataAppleTouchIcon : NSObject

@property (nonatomic, readonly) NSString *rel;
@property (nonatomic, readonly) NSString *sizes;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) NSString *urlString; // Absolute.

@end


@interface RSHTMLMetadataFeedLink : NSObject

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) NSString *urlString; // Absolute.

@end

@interface RSHTMLOpenGraphProperties : NSObject

// TODO: the rest. At this writing (Nov. 26, 2017) I just care about og:image.
// See http://ogp.me/

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RSHTMLTag *> *)tags;

@property (nonatomic, readonly) NSArray <RSHTMLOpenGraphImage *> *images;

@end

@interface RSHTMLOpenGraphImage : NSObject

@property (nonatomic, readonly) NSString *url;
@property (nonatomic, readonly) NSString *secureURL;
@property (nonatomic, readonly) NSString *mimeType;
@property (nonatomic, readonly) CGFloat width;
@property (nonatomic, readonly) CGFloat height;
@property (nonatomic, readonly) NSString *altText;

@end

@interface RSHTMLTwitterProperties : NSObject

// TODO: the rest. At this writing (Nov. 26, 2017) I just care about twitter:image:src.

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RSHTMLTag *> *)tags;

@property (nonatomic, readonly) NSString *imageURL; // twitter:image:src

@end

