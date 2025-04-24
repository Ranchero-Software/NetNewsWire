//
//  RSHTMLMetadata.m
//  RSParser
//
//  Created by Brent Simmons on 3/6/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

#import "RSHTMLMetadata.h"
#import "RSParserInternal.h"
#import "RSHTMLTag.h"



static NSString *urlStringFromDictionary(NSDictionary *d);
static NSString *absoluteURLStringWithRelativeURLString(NSString *relativeURLString, NSString *baseURLString);
static NSString *absoluteURLStringWithDictionary(NSDictionary *d, NSString *baseURLString);
static NSArray *objectsOfClassWithTags(Class class, NSArray *tags, NSString *baseURLString);
static NSString *relValue(NSDictionary *d);
static BOOL typeIsFeedType(NSString *type);

static NSString *kIconRelValue = @"icon";
static NSString *kHrefKey = @"href";
static NSString *kSrcKey = @"src";
static NSString *kAppleTouchIconValue = @"apple-touch-icon";
static NSString *kAppleTouchIconPrecomposedValue = @"apple-touch-icon-precomposed";
static NSString *kSizesKey = @"sizes";
static NSString *kTitleKey = @"title";
static NSString *kRelKey = @"rel";
static NSString *kAlternateKey = @"alternate";
static NSString *kRSSSuffix = @"/rss+xml";
static NSString *kAtomSuffix = @"/atom+xml";
static NSString *kJSONSuffix = @"/json";
static NSString *kTypeKey = @"type";

@interface RSHTMLMetadataAppleTouchIcon ()

- (instancetype)initWithTag:(RSHTMLTag *)tag baseURLString:(NSString *)baseURLString;

@end


@interface RSHTMLMetadataFeedLink ()

- (instancetype)initWithTag:(RSHTMLTag *)tag baseURLString:(NSString *)baseURLString;

@end

@interface RSHTMLMetadataFavicon ()

- (instancetype)initWithTag:(RSHTMLTag *)tag baseURLString:(NSString *)baseURLString;

@end

@implementation RSHTMLMetadata

#pragma mark - Init

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RSHTMLTag *> *)tags {

	self = [super init];
	if (!self) {
		return nil;
	}

	_baseURLString = urlString;
	_tags = tags;

	_favicons = [self resolvedFaviconLinks];
	
	NSArray *appleTouchIconTags = [self appleTouchIconTags];
	_appleTouchIcons = objectsOfClassWithTags([RSHTMLMetadataAppleTouchIcon class], appleTouchIconTags, urlString);

	NSArray *feedLinkTags = [self feedLinkTags];
	_feedLinks = objectsOfClassWithTags([RSHTMLMetadataFeedLink class], feedLinkTags, urlString);

	_openGraphProperties = [[RSHTMLOpenGraphProperties alloc] initWithURLString:urlString tags:tags];
	_twitterProperties = [[RSHTMLTwitterProperties alloc] initWithURLString:urlString tags:tags];
	
	return self;
}

#pragma mark - Private

- (NSArray<RSHTMLTag *> *)linkTagsWithMatchingRel:(NSString *)valueToMatch {

	// Case-insensitive; matches a whitespace-delimited word

	NSMutableArray<RSHTMLTag *> *tags = [NSMutableArray array];

	for (RSHTMLTag *tag in self.tags) {

		if (tag.type != RSHTMLTagTypeLink || RSParserStringIsEmpty(urlStringFromDictionary(tag.attributes))) {
			continue;
		}
		NSString *oneRelValue = relValue(tag.attributes);
		if (oneRelValue) {
			NSArray *relValues = [oneRelValue componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

			for (NSString *relValue in relValues) {
				if ([relValue compare:valueToMatch options:NSCaseInsensitiveSearch] == NSOrderedSame) {
					[tags addObject:tag];
					break;
				}
			}
		}
	}

	return tags;
}


- (NSArray<RSHTMLTag *> *)appleTouchIconTags {

	NSMutableArray *tags = [NSMutableArray new];

	for (RSHTMLTag *tag in self.tags) {

		if (tag.type != RSHTMLTagTypeLink) {
			continue;
		}
		NSString *oneRelValue = relValue(tag.attributes).lowercaseString;
		if ([oneRelValue isEqualToString:kAppleTouchIconValue] || [oneRelValue isEqualToString:kAppleTouchIconPrecomposedValue]) {
			[tags addObject:tag];
		}
	}

	return tags;
}


- (NSArray<RSHTMLTag *> *)feedLinkTags {

	NSMutableArray *tags = [NSMutableArray new];

	for (RSHTMLTag *tag in self.tags) {

		if (tag.type != RSHTMLTagTypeLink) {
			continue;
		}

		NSDictionary *oneDictionary = tag.attributes;
		NSString *oneRelValue = relValue(oneDictionary).lowercaseString;
		if (![oneRelValue isEqualToString:kAlternateKey]) {
			continue;
		}

		NSString *oneType = [oneDictionary rsparser_objectForCaseInsensitiveKey:kTypeKey];
		if (!typeIsFeedType(oneType)) {
			continue;
		}

		if (RSParserStringIsEmpty(urlStringFromDictionary(oneDictionary))) {
			continue;
		}

		[tags addObject:tag];
	}

	return tags;
}

- (NSArray<NSString *> *)faviconLinks {
	NSMutableArray *urls = [NSMutableArray array];

	for (RSHTMLMetadataFavicon *favicon in self.favicons) {
		[urls addObject:favicon.urlString];
	}

	return urls;
}

- (NSArray<RSHTMLMetadataFavicon *> *)resolvedFaviconLinks {
	NSArray<RSHTMLTag *> *tags = [self linkTagsWithMatchingRel:kIconRelValue];
	NSMutableArray *links = [NSMutableArray array];
	NSMutableSet<NSString *> *seenHrefs = [NSMutableSet setWithCapacity:tags.count];

	for (RSHTMLTag *tag in tags) {
		RSHTMLMetadataFavicon *link = [[RSHTMLMetadataFavicon alloc] initWithTag:tag baseURLString:self.baseURLString];
		NSString *urlString = link.urlString;
		if (urlString == nil) {
			continue;
		}
		if (![seenHrefs containsObject:urlString]) {
			[links addObject:link];
			[seenHrefs addObject:urlString];
		}
	}

	return links;
}

@end


static NSString *relValue(NSDictionary *d) {

	return [d rsparser_objectForCaseInsensitiveKey:kRelKey];
}


static NSString *urlStringFromDictionary(NSDictionary *d) {

	NSString *urlString = [d rsparser_objectForCaseInsensitiveKey:kHrefKey];
	if (urlString) {
		return urlString;
	}

	return [d rsparser_objectForCaseInsensitiveKey:kSrcKey];
}


static NSString *absoluteURLStringWithRelativeURLString(NSString *relativeURLString, NSString *baseURLString) {

	NSURL *url = [NSURL URLWithString:baseURLString];
	if (!url) {
		return nil;
	}

	NSURL *absoluteURL = [NSURL URLWithString:relativeURLString relativeToURL:url];
	return absoluteURL.absoluteURL.standardizedURL.absoluteString;
}


static NSString *absoluteURLStringWithDictionary(NSDictionary *d, NSString *baseURLString) {

	NSString *urlString = urlStringFromDictionary(d);
	if (RSParserStringIsEmpty(urlString)) {
		return nil;
	}
	return absoluteURLStringWithRelativeURLString(urlString, baseURLString);
}


static NSArray *objectsOfClassWithTags(Class class, NSArray *tags, NSString *baseURLString) {

	NSMutableArray *objects = [NSMutableArray new];

	for (RSHTMLTag *tag in tags) {

		id oneObject = [[class alloc] initWithTag:tag baseURLString:baseURLString];
		if (oneObject) {
			[objects addObject:oneObject];
		}
	}

	return objects;
}


static BOOL typeIsFeedType(NSString *type) {

	type = type.lowercaseString;
	return [type hasSuffix:kRSSSuffix] || [type hasSuffix:kAtomSuffix] || [type hasSuffix:kJSONSuffix];
}


@implementation RSHTMLMetadataAppleTouchIcon

- (instancetype)initWithTag:(RSHTMLTag *)tag baseURLString:(NSString *)baseURLString {

	self = [super init];
	if (!self) {
		return nil;
	}

	NSDictionary *d = tag.attributes;
	_urlString = absoluteURLStringWithDictionary(d, baseURLString);
	_sizes = [d rsparser_objectForCaseInsensitiveKey:kSizesKey];
	_rel = [d rsparser_objectForCaseInsensitiveKey:kRelKey];

	_size = CGSizeZero;
	if (_sizes) {
		NSArray *components = [_sizes componentsSeparatedByString:@"x"];
		if (components.count == 2) {
			CGFloat width = [components[0] floatValue];
			CGFloat height = [components[1] floatValue];
			_size = CGSizeMake(width, height);
		}
	}
	
	return self;
}

@end


@implementation RSHTMLMetadataFeedLink

- (instancetype)initWithTag:(RSHTMLTag *)tag baseURLString:(NSString *)baseURLString {

	self = [super init];
	if (!self) {
		return nil;
	}

	NSDictionary *d = tag.attributes;
	_urlString = absoluteURLStringWithDictionary(d, baseURLString);
	_title = [d rsparser_objectForCaseInsensitiveKey:kTitleKey];
	_type = [d rsparser_objectForCaseInsensitiveKey:kTypeKey];

	return self;
}

@end

@implementation RSHTMLMetadataFavicon

- (instancetype)initWithTag:(RSHTMLTag *)tag baseURLString:(NSString *)baseURLString {

	self = [super init];
	if (!self) {
		return nil;
	}

	NSDictionary *d = tag.attributes;
	_urlString = absoluteURLStringWithDictionary(d, baseURLString);
	_type = [d rsparser_objectForCaseInsensitiveKey:kTypeKey];

	return self;
}

@end

@interface RSHTMLOpenGraphImage ()

@property (nonatomic, readwrite) NSString *url;
@property (nonatomic, readwrite) NSString *secureURL;
@property (nonatomic, readwrite) NSString *mimeType;
@property (nonatomic, readwrite) CGFloat width;
@property (nonatomic, readwrite) CGFloat height;
@property (nonatomic, readwrite) NSString *altText;

@end

@implementation RSHTMLOpenGraphImage


@end

@interface RSHTMLOpenGraphProperties ()

@property (nonatomic) NSMutableArray *ogImages;
@end

@implementation RSHTMLOpenGraphProperties

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RSHTMLTag *> *)tags {

	self = [super init];
	if (!self) {
		return nil;
	}

	_ogImages = [NSMutableArray new];

	[self parseTags:tags];
	return self;
}


- (RSHTMLOpenGraphImage *)currentImage {

	return self.ogImages.lastObject;
}


- (RSHTMLOpenGraphImage *)pushImage {

	RSHTMLOpenGraphImage *image = [RSHTMLOpenGraphImage new];
	[self.ogImages addObject:image];
	return image;
}

- (RSHTMLOpenGraphImage *)ensureImage {

	RSHTMLOpenGraphImage *image = [self currentImage];
	if (image != nil) {
		return image;
	}
	return [self pushImage];
}


- (NSArray *)images {

	return self.ogImages;
}

static NSString *ogPrefix = @"og:";
static NSString *ogImage = @"og:image";
static NSString *ogImageURL = @"og:image:url";
static NSString *ogImageSecureURL = @"og:image:secure_url";
static NSString *ogImageType = @"og:image:type";
static NSString *ogImageWidth = @"og:image:width";
static NSString *ogImageHeight = @"og:image:height";
static NSString *ogImageAlt = @"og:image:alt";
static NSString *ogPropertyKey = @"property";
static NSString *ogContentKey = @"content";

- (void)parseTags:(NSArray *)tags {

	for (RSHTMLTag *tag in tags) {

		if (tag.type != RSHTMLTagTypeMeta) {
			continue;
		}

		NSString *propertyName = tag.attributes[ogPropertyKey];
		if (!propertyName || ![propertyName hasPrefix:ogPrefix]) {
			continue;
		}
		NSString *content = tag.attributes[ogContentKey];
		if (!content) {
			continue;
		}

		if ([propertyName isEqualToString:ogImage]) {
			RSHTMLOpenGraphImage *image = [self currentImage];
			if (!image || image.url) { // Most likely case, since og:image will probably appear before other image attributes.
				image = [self pushImage];
			}
			image.url = content;
		}

		else if ([propertyName isEqualToString:ogImageURL]) {
			[self ensureImage].url = content;
		}
		else if ([propertyName isEqualToString:ogImageSecureURL]) {
			[self ensureImage].secureURL = content;
		}
		else if ([propertyName isEqualToString:ogImageType]) {
			[self ensureImage].mimeType = content;
		}
		else if ([propertyName isEqualToString:ogImageAlt]) {
			[self ensureImage].altText = content;
		}
		else if ([propertyName isEqualToString:ogImageWidth]) {
			[self ensureImage].width = [content floatValue];
		}
		else if ([propertyName isEqualToString:ogImageHeight]) {
			[self ensureImage].height = [content floatValue];
		}
	}
}

@end

@implementation RSHTMLTwitterProperties

static NSString *twitterNameKey = @"name";
static NSString *twitterContentKey = @"content";
static NSString *twitterImageSrc = @"twitter:image:src";

- (instancetype)initWithURLString:(NSString *)urlString tags:(NSArray <RSHTMLTag *> *)tags {

	self = [super init];
	if (!self) {
		return nil;
	}

	for (RSHTMLTag *tag in tags) {

		if (tag.type != RSHTMLTagTypeMeta) {
			continue;
		}
		NSString *name = tag.attributes[twitterNameKey];
		if (!name || ![name isEqualToString:twitterImageSrc]) {
			continue;
		}
		NSString *content = tag.attributes[twitterContentKey];
		if (!content || content.length < 1) {
			continue;
		}
		_imageURL = content;
		break;
	}

	return self;
}

@end

