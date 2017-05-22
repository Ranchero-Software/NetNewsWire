//
//  VSThemeLoader.h
//  Q Branch LLC
//
//  Created by Brent Simmons on 6/26/13.
//  Copyright (c) 2012 Q Branch LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@class VSTheme;

@interface VSThemeLoader : NSObject

// Just use -init if you want the default DB5.plist in the normal place.
- (instancetype)initWithFilepath:(NSString *)f;

@property (nonatomic, strong, readonly) VSTheme *defaultTheme;
@property (nonatomic, strong, readonly) NSArray *themes;

- (VSTheme *)themeNamed:(NSString *)themeName;

@end
