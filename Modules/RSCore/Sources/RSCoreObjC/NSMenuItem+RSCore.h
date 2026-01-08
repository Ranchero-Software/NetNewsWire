//
//  NSMenuItem+RSCore.h
//  RSCore
//
//  Created by Brent Simmons on 1/5/26.
//

#if TARGET_OS_MAC && !TARGET_OS_IPHONE

@import AppKit;

@interface NSMenuItem (RSCore)

/// When YES, the menu item’s image will be shown (if it exists) despite icon disabling.
/// Defaults to NO.
@property (nonatomic, assign) BOOL rs_shouldShowImage;

/// Disables icons in all menu items (except where `rs_shouldShowImage == YES`)
/// and those that are likely toolbar item representations.
///
/// Call +[NSMenuItem rs_disableIcons] early (from AppDelegate init is good).
+ (void)rs_disableIcons;

@end

#endif
