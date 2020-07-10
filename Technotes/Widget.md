#  Widget

## Supported Widget Styles

The NetNewsWire iOS widget supports the `systemSmall` and `systemMedium` styles. 

The `systemSmall` style displays the current Today and Unread counts; `systemMedium` displays the latest two articles along with current 
Today and Unread count.

## Passing Data from the App to the Widget

Data is made available to the widget by encoding JSON data and saving it to a file in a directory available to app extensions. 


```
struct WidgetData: Codable {

    let currentUnreadCount: Int 
    let currentTodayCount: Int
    let latestArticles: [LatestArticle]
    let lastUpdateTime: Date

}

struct LatestArticle: Codable {

    let feedTitle: String
    let articleTitle: String?
    let articleSummary: String?
    let feedIcon: Data? // Base64 encoded image data
    let pubDate: String

}
```

## When is JSON Data Saved?

1. On `unreadCountDidChange`
2. After a background refresh
3. When the app enters the background

After JSON data is saved, Widget timelines are reloaded.


