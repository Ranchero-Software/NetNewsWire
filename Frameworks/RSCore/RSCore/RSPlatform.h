//
//  RSPlatform.h
//  RSCore
//
//  Created by Brent Simmons on 3/25/15.
//  Copyright (c) 2015 Ranchero Software, LLC. All rights reserved.
//

@import Foundation;

/*Mac: ~/Application Support/AppName/

 If nil, gets appName from Info.plist -- @"CFBundleExecutable" key.
 It creates the folder and intermediate folders if necessary.

 If something goes wrong it returns nil. The error is NSLogged.
 Panic, at that point, is strongly indicated.*/

NS_ASSUME_NONNULL_BEGIN

NSString * _Nullable RSDataFolder(NSString * _Nullable appName);

/*Path to file in folder specified by RSDataFolder.
 appName may be nil -- it's passed to RSDataFolder.*/

NSString * _Nullable RSDataFile(NSString * _Nullable appName, NSString *fileName);

/* app support/appName/folderName/ */

NSString * _Nullable RSDataSubfolder(NSString * _Nullable appName, NSString *folderName);

/* app support/appName/folderName/filename */

NSString * _Nullable RSDataSubfolderFile(NSString * _Nullable appName, NSString *folderName, NSString *filename);

NS_ASSUME_NONNULL_END


#if TARGET_OS_IPHONE

#define RS_IMAGE UIImage

#else

#define RS_IMAGE NSImage

#endif

