# Themes

## `.nnwtheme` Structure

An `.nnwtheme` comprises of three files:
- `Info.plist`
- `template.html`
- `stylesheet.css`

### Info.plist
The `Info.plist` requires the following keys/types:

|Key|Type|Notes|
|---|---|---|
|`ThemeIdentifier`|`String`|Unique identifier for the theme, e.g. using reverse domain name.|
|`Name`|`String`|Theme name|
|`CreatorHomePage`|`String`||
|`CreatorName`|`String`||
|`Version`|`Integer`||

### template.html
This provides a starting point for editing the structure of the page. Theme variables are documented in the header.

### stylesheet.css
This provides a starting point for editing the style of the page. 

## Add Themes Directly to NetNewsWire with URL Scheme
On iOS and macOS, themes can be opened directly in NetNewsWire using the below URL scheme:

`netnewswire://theme/add?url={url}`

When using this URL scheme the theme being shared must be zipped.

Parameters:
- `url`: (mandatory, URL-encoded): The theme's location.
