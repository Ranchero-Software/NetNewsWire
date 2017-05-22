//
//  RSMacroProcessor.h
//  RSCore
//
//  Created by Brent Simmons on 10/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface RSMacroProcessor : NSObject

+ (NSString *)renderedTextWithTemplate:(NSString *)templateString substitutions:(NSDictionary *)substitutions macroStart:(NSString *)macroStart macroEnd:(NSString *)macroEnd;

@end

NS_ASSUME_NONNULL_END
