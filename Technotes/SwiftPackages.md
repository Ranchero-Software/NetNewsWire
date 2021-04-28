# Swift Packages

NetNewsWire uses the [Swift Package Manager](https://swift.org/package-manager/) to include shared frameworks. At this writing (April 2021) they are RSCore, RSDatabase, RSWeb, and RSParser. NetNewsWire also utilizes four packages hosted within the NetNewsWire repository itself: Articles, ArticlesDatabase, Secrets, and SyncDatabase.

After your first checkout, when you open the project Xcode will automatically download the external packages and their dependencies. Until this process is complete, you will not be able to build or run NetNewsWire. On a fast internet connection this will normally only take a few seconds.

Xcode automatically keeps these packages up to date on subsequent occasions you open the Xcode project. Unless you are actively working on changes to the packages at source, this should be all that is necessary. However, if you do need to force an update you co do this in Xcode by selecting File > Swift Packages > Update to Latest Package Versions.
