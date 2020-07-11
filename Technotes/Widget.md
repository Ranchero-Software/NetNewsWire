#  Widget

## Supported Widget Styles

The NetNewsWire iOS widget supports the `systemSmall` and `systemMedium` styles. 

For the purpose of this PoC: the `systemSmall` style displays the current Today and Unread counts; `systemMedium` displays the latest two articles. 

## Passing Data from the App to the Widget

Data is made available to the widget by encoding smart feed and article data as JSON, and saving it to a file in a directory available to app extensions. 

Three `struct`s are responsible for this:

- `WidgetDataEncoder` (which is available to the app);
- `WidgetDataDecoder` (which is available to the widget); and,
- `WidgetData` (which is available to both app and widget, and includes the data neccessary for the widget to function)

## When is JSON Data Saved?

1. When the app enters the background (monitored via the `scenePhase` changing (tested)); or,
2. After a background refresh (untested at the time of writing)

Encoding tasks are fenced in 
```
UIApplication.shared.beginBackgroundTask
_{ encoding task }_
UIApplication.shared.endBackgroundTask
```
in order to ensure that the file can be written with sufficient time to spare. 

After JSON data is saved, Widget timelines are reloaded. 



