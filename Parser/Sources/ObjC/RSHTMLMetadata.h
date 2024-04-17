//
//  RSHTMLMetadata.h
//  RSParser
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;
@import CoreGraphics;

@class RSHTMLMetadataFeedLink;
@class RSHTMLMetadataAppleTouchIcon;
@class RSHTMLMetadataFavicon;
@class RSHTMLOpenGraphProperties;
@class RSHTMLOpenGraphImage;
@class RSHTMLTag;
@class RSHTMLTwitterProperties;

NS_ASSUME_NONNULL_BEGIN

__attribute__((swift_attr("@Sendable")))
@interface RSHTMLMetadata : NSObject

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RSHTMLTag *> *)tags;

@property (nonatomic, readonly) NSString *baseURLString;
@property (nonatomic, readonly) NSArray <RSHTMLTag *> *tags;

@property (nonatomic, readonly) NSArray <NSString *> *faviconLinks DEPRECATED_MSG_ATTRIBUTE("Use the favicons property instead.");
@property (nonatomic, readonly) NSArray <RSHTMLMetadataFavicon *> *favicons;
@property (nonatomic, readonly) NSArray <RSHTMLMetadataAppleTouchIcon *> *appleTouchIcons;
@property (nonatomic, readonly) NSArray <RSHTMLMetadataFeedLink *> *feedLinks;

@property (nonatomic, readonly) RSHTMLOpenGraphProperties *openGraphProperties;
@property (nonatomic, readonly) RSHTMLTwitterProperties *twitterProperties;

@end


@interface RSHTMLMetadataAppleTouchIcon : NSObject

@property (nonatomic, readonly) NSString *rel;
@property (nonatomic, nullable, readonly) NSString *sizes;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, nullable, readonly) NSString *urlString; // Absolute.

@end


@interface RSHTMLMetadataFeedLink : NSObject

@property (nonatomic, nullable, readonly) NSString *title;
@property (nonatomic, nullable, readonly) NSString *type;
@property (nonatomic, nullable, readonly) NSString *urlString; // Absolute.

@end

@interface RSHTMLMetadataFavicon : NSObject

@property (nonatomic, nullable, readonly) NSString *type;
@property (nonatomic, nullable, readonly) NSString *urlString;

@end

@interface RSHTMLOpenGraphProperties : NSObject

// TODO: the rest. At this writing (Nov. 26, 2017) I just care about og:image.
// See http://ogp.me/

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RSHTMLTag *> *)tags;

@property (nonatomic, readonly) NSArray <RSHTMLOpenGraphImage *> *images;

@end

@interface RSHTMLOpenGraphImage : NSObject

@property (nonatomic, nullable, readonly) NSString *url;
@property (nonatomic, nullable, readonly) NSString *secureURL;
@property (nonatomic, nullable, readonly) NSString *mimeType;
@property (nonatomic, readonly) CGFloat width;
@property (nonatomic, readonly) CGFloat height;
@property (nonatomic, nullable, readonly) NSString *altText;

@end

@interface RSHTMLTwitterProperties : NSObject

// TODO: the rest. At this writing (Nov. 26, 2017) I just care about twitter:image:src.

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RSHTMLTag *> *)tags;

@property (nonatomic, nullable, readonly) NSString *imageURL; // twitter:image:src

@end

NS_ASSUME_NONNULL_END
