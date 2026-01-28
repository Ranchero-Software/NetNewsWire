//
//  NSSharingService+Extension.h
//  RSCore
//
//  Created by Brent Simmons on 11/3/24.
//

#if TARGET_OS_MAC && !TARGET_OS_IPHONE

@import AppKit;

@interface NSSharingService (NoDeprecationWarning)

// The only way to create custom UI — a Share menu, for instance —
// is to use the unfortunately deprecated
// +[NSSharingService sharingServicesForItems:].
// This cover method allows us to not generate a warning.
//
// We know it’s deprecated, and we don’t want to be bugged
// about it every time we build. (If anyone from Apple
// is reading this — a replacement would be very welcome!)

+ (NSArray *)sharingServicesForItems_noDeprecationWarning:(NSArray *)items;

@end

#endif
