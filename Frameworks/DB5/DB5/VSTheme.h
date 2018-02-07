//
//  VSTheme.h
//  Q Branch LLC
//
//  Created by Brent Simmons on 6/26/13.
//  Copyright (c) 2012 Q Branch LLC. All rights reserved.
//

@import AppKit;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, VSTextCaseTransform) {
    VSTextCaseTransformNone,
    VSTextCaseTransformUpper,
    VSTextCaseTransformLower
};


@class VSAnimationSpecifier;

@interface VSTheme : NSObject

- (id)initWithDictionary:(NSDictionary *)themeDictionary;

@property (nonatomic, strong) NSString *name;
@property (nonatomic, weak) VSTheme *parentTheme; /*can inherit*/

- (nullable id)objectForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (nullable NSString *)stringForKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;
- (CGFloat)floatForKey:(NSString *)key;

#if TARGET_OS_IPHONE

- (nullable UIImage *)imageForKey:(NSString *)key; /*Via UIImage imageNamed:*/
- (UIColor *)colorForKey:(NSString *)key; /*123ABC or #123ABC: 6 digits, leading # allowed but not required*/
- (UIEdgeInsets)edgeInsetsForKey:(NSString *)key; /*xTop, xLeft, xRight, xBottom keys*/
- (UIFont *)fontForKey:(NSString *)key; /*x and xSize keys*/

#else /*Mac*/

- (nullable NSImage *)imageForKey:(NSString *)key; /*Via NSImage imageNamed:*/
- (NSColor *)colorForKey:(NSString *)key; /*123ABC or #123ABC: 6 digits, leading # allowed but not required*/
- (NSColor *)colorWithAlphaForKey:(NSString *)key; /*key and keyAlpha*/
- (NSEdgeInsets)edgeInsetsForKey:(NSString *)key; /*xTop, xLeft, xRight, xBottom keys*/
- (NSFont *)fontForKey:(NSString *)key; /*x and xSize keys*/

#endif


- (CGPoint)pointForKey:(NSString *)key; /*xX and xY keys*/
- (CGSize)sizeForKey:(NSString *)key; /*xWidth and xHeight keys*/
- (NSTimeInterval)timeIntervalForKey:(NSString *)key;

#if TARGET_OS_IPHONE

- (UIViewAnimationOptions)curveForKey:(NSString *)key; /*Possible values: easeinout, easeout, easein, linear*/
- (VSAnimationSpecifier *)animationSpecifierForKey:(NSString *)key; /*xDuration, xDelay, xCurve*/
#endif

- (VSTextCaseTransform)textCaseTransformForKey:(NSString *)key; /*lowercase or uppercase -- returns VSTextCaseTransformNone*/
- (NSString *)string:(NSString *)s transformedWithTextCaseTransformKey:(NSString *)key;

@end


NSString *VSThemeSpecifierPlusKey(NSString *specifier, NSString *key); /*specifier + . + key*/



#if TARGET_OS_IPHONE

@interface VSTheme (Animations)

- (void)animateWithAnimationSpecifierKey:(NSString *)animationSpecifierKey animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;

@end


@interface VSAnimationSpecifier : NSObject

@property (nonatomic, assign) NSTimeInterval delay;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) UIViewAnimationOptions curve;

@end

#endif

NS_ASSUME_NONNULL_END
