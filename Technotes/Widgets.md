# Widgets on iOS

There are _currently_ seven widgets available for iOS:

- 1x small widget that displays the current count of each of the Smart Feeds
- 3x medium widgets—one for each of the smart feeds.
- 3x large widgets—bigger versions of the medium widgets

## Widget Data
The widget does not have access to the parent app's database. To surface data to the widget, a small amount of article data is encoded to JSON (see `WidgetDataEncoder`) and saved to the AppGroup container. 

Widget data is written at two points:

1. As part of a background refresh
2. When the scene enters the background

The widget timeline is refreshed—via `WidgetCenter.shared.reloadAllTimelines()`—after each of the above.

## Deep Links
The medium widgets support deep links for each of the articles that are surfaced.

If the user taps on an unread article in the unread widget, the widget opens the parent app with a deep link URL (see `WidgetDeepLink`), for example: `nnw://showunread?id={articeID}`. Once the app is opened, `scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>)` is called and it is then determined what should be presented to the user based on the URL. If there is no `id` parameter—the user has tapped on a small widget or a non-linked item in a medium widget—the relevant smart feed controller is displayed.


## Data Models
```swift
struct WidgetData: Codable {

    let currentUnreadCount: Int
    let currentTodayCount: Int
    let currentStarredCount: Int
    let unreadArticles: [LatestArticle]
    let starredArticles: [LatestArticle]
    let todayArticles: [LatestArticle]
    let lastUpdateTime: Date

}

struct LatestArticle: Codable, Identifiable {

    var id: String // articleID
    let feedTitle: String
    let articleTitle: String?
    let articleSummary: String?
    let feedIcon: Data? // Base64 encoded image
    let pubDate: String

}
```


