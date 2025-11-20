//
//  NSSharingService+Extension.m
//  RSCore
//
//  Created by Brent Simmons on 11/3/24.
//

#if TARGET_OS_MAC && !TARGET_OS_IPHONE

#import "NSSharingService+Extension.h"

@implementation NSSharingService (NoDeprecationWarning)

+ (NSArray *)sharingServicesForItems_noDeprecationWarning:(NSArray *)items {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

	return [NSSharingService sharingServicesForItems:items];

#pragma clang diagnostic pop
}

@end

#endif
