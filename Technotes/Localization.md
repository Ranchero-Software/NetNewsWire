# Localization

NetNewsWire is an Internationalized and Localized app.

## Internationalization

`Internationalized` means that, at code-level, we don't use locale-dependent strings. Instead, in code we use a key-based approach. Generally, this takes the form of:

`UIKit` or `AppKit` — using `NSLocalizedString`:

```swift
let messageFormat = NSLocalizedString("alert.title.open-articles-in-browser.%ld", comment: "Are you sure you want to open %ld articles in your browser?")
alert.messageText = String.localizedStringWithFormat(messageFormat, urlStrings.count)
```

or, in `SwiftUI` — using the `Text` struct:

```swift
Text("alert.title.remove-account.\(viewModel.accountToDelete?.nameForDisplay ?? "")", comment: "Are you sure you want to remove “%@“?")
```

### Key Format

All keys are lower cased and follow the `dot.separated` UI element name -> `hyphen-separated` string descriptor -> `dot.separated` variable list format, e.g.:

```
alert.title.open-articles-in-browser.%ld
button.title.close
```

### Comments

Whether using `NSLocalizedString` or `Text`, a `comment` must be provided. This will generally be a reference to the string in English. However, where a key contains multiple variables, the ordering of the variables must be specified in the comment.


## Localization

All of NetNewsWire's strings in code are localized in external resources — `.strings` or `.stringsdict`. Each target has its own `Localizable.strings` (and, where necessary, `.stringsdict`) files. All Storyboards are also localized. 

### Adding New Strings

If you are developing a new feature that introduces new strings to the code base, follow these general guidelines:

- Check if there is an existing string in `Localizable.strings` that meets your needs. If there is, use that.
- If there isn't:
    - Add your string in code following the key and comment rules above
    - Run `Export Localizations`
    - Open the `en.xcloc` file and provide the new translations.
    - Save the `en.xcloc` file.
    - Run `Import Localizations` 
    - Select `en.xcloc` and Import. 

### Updating Existing Translations 

Update the Development Language translation first:

- Run `Export Localizations`
- Open the `en.xcloc` file and provide the new translations.
- Save the `en.xcloc` file.
- Run `Import Localizations` 
- Select `en.xcloc` and Import. 

Then update other lanaguages:

- Run `Export Localizations`
- Open the `en-GB.xcloc` file and provide the new translations.
- Save the `en-GB.xcloc` file.
- Run `Import Localizations` 
- Select `en-GB.xcloc` and Import. 

