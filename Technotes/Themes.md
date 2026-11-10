# Themes

## `.nnwtheme` Structure

An `.nnwtheme` comprises of these files:
- `Info.plist`
- `template.html`
- `template7.3.html` (optional)
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

These keys are optional. They fill in the theme's Get Info window in the Finder, and NetNewsWire ignores them:

|Key|Type|Notes|
|---|---|---|
|`CFBundleShortVersionString`|`String`|The version, e.g. `1.2`.|
|`NSHumanReadableCopyright`|`String`|The copyright, e.g. `Copyright © 2026 Your Name`.|

### template.html
This provides a starting point for editing the structure of the page. Theme variables are documented in the header.

The page loads with the article's link as its base URL, else the feed's home page, else the feed's URL. Relative URLs resolve against that site, so a theme can't load its own `.js`, image, or font files. Put scripts inline in the template; they run only when the Article JavaScript setting is on, which is the default. Articles synced through the Google Reader API have no link of their own, so a script shouldn't assume `document.baseURI` is the article's URL.

### template7.3.html
NetNewsWire 7.3 and later use this file instead of `template.html` when a theme includes it, and older versions ignore it. Put `[[primary_media]]` and `[[enclosures]]` here, since older versions would show them as literal text. [Verdana Revival](../Themes/Verdana%20Revival.nnwtheme/template7.3.html) is an example.

### stylesheet.css
This provides a starting point for editing the style of the page. 

## Article Media

NetNewsWire 7.3 shows audio, video, and images from an article's enclosures, Media RSS, and similar elements with two tags:

|Tag|Contents|
|---|---|
|`[[primary_media]]`|The article's main media, usually placed above the body: a video, else audio with the article's image, else the article's image. Empty when there's nothing to show.|
|`[[enclosures]]`|The article's other audio, video, and images.|

The rules:
- The article's image is its own image, else its first image enclosure, else its thumbnail.
- Media already in the body is left out of both tags, including a resized copy of an image.
- A post with no title and a body under 2,048 characters, such as a Mastodon post, keeps its images in `[[enclosures]]`.
- A template with `[[enclosures]]` but no `[[primary_media]]` gets the article's own image in the enclosures. The thumbnail isn't shown.
- A template with no `[[enclosures]]` gets the enclosures after the body, and the body is wrapped in a `<div>`, which can break selectors such as `.articleBody > p`.
- NetNewsWire looks for each tag's literal text anywhere in the template, so don't write a tag in a comment.

The markup has no inline styles. `core.css` sets default margins, and themes can style these classes:

```html
<div class="nnw-primary-media">
  <div class="nnw-primary-image">
    <img src="…" alt="…" width="…" height="…">
    <div class="nnw-primary-image-caption">…</div>
  </div>
  <div class="nnw-enclosure nnw-enclosure-audio">…</div>
</div>

<div class="nnw-enclosures">
  <div class="nnw-enclosure nnw-enclosure-image"><img src="…" alt=""></div>
  <div class="nnw-enclosure nnw-enclosure-audio">
    <audio controls preload="none" src="…"></audio>
    <div class="nnw-enclosure-caption">…</div>
  </div>
  <div class="nnw-enclosure nnw-enclosure-video"><video controls src="…"></video></div>
</div>
```

A video in `[[primary_media]]` uses the same `nnw-enclosure-video` block, and a YouTube video is an `<iframe>` in that block. An image has `width` and `height` only when the feed gives both. A caption appears only when there's text for it, and `nnw-primary-image-caption` only when the image's title differs from the article's.

## Add Themes Directly to NetNewsWire with URL Scheme
On iOS and macOS, themes can be opened directly in NetNewsWire using the below URL scheme:

`netnewswire://theme/add?url={url}`

When using this URL scheme the theme being shared must be zipped.

Parameters:
- `url`: (mandatory, URL-encoded): The theme's location.
