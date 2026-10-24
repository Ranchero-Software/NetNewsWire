# Reader-App

Eigenständige SwiftUI-App für macOS, iOS und iPadOS ab 27. Das alte NetNewsWire-Projekt bleibt während der Abnahme bestehen. Der neue App-Target bindet ausschließlich `ReaderKit` ein und übernimmt weder die alten AppKit-/UIKit-Controller noch Objective-C-/FMDB-, CloudKit-, Widget- oder Erweiterungstargets.

## Bauen

`python3 ReaderApp/generate_project.py` erzeugt `Reader.xcodeproj` und den gemeinsamen Testplan aus den aktuellen Pakettests. Anschließend das Projekt und die Scheme `Reader` öffnen. Debug verwendet `eu.mpwg.reader.debug`, Release `eu.mpwg.reader`. Jeder Build speichert unter seinem eigenen Application-Support-Verzeichnis; es gibt keine Migration bestehender NetNewsWire-Datenbanken.

Für lokale Mac-UI-Tests muss Xcode den Test-Runner einschließlich seiner eingebetteten Testbundles gültig signieren. Lokal ist eine Ad-hoc-Signatur mit `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=YES DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual` möglich. `CODE_SIGNING_ALLOWED=NO` genügt für einen Mac-Build, erzeugt aber keinen ausführbaren, gültig signierten UI-Test-Runner. Vor `test-without-building` die Signatur mit `codesign --verify --deep --strict` prüfen.

`ReaderSmokeTests` startet mit `--ui-testing` und einem isolierten In-Memory-Store; keine persönlichen Abonnements oder Zugangsdaten sind dafür nötig. Der gemeinsame Testplan enthält Fachtests mit Swift Testing und UI-Automation mit XCTest. Der UIKit-Modernisierungsschnitt besteht im neuen SwiftUI-`App`-/`WindowGroup`-Lebenszyklus; es gibt keinen globalen Zugriff auf die aktuelle Szene, den Hauptbildschirm oder AppDelegate-Zustand.

## Plattformverträge

- Jede Szene besitzt Auswahl, Suche, Sheets und Abfragegeneration selbst; Repository und kontoabhängige Dienste sind gemeinsam.
- Eine Szene darf die laufende Arbeit einer anderen Szene nicht suspendieren. Externe Links werden über SwiftUI `Link` geöffnet.
- Layout folgt dem verfügbaren Fenster und den systemseitigen Safe Areas. Keine geräteweite Portrait-/Landscape- oder Displaygrößenannahme.
- Artikel verwenden `WebView`/`WebPage`; Inhalts-JavaScript ist deaktiviert. Die generierte HTML-Ansicht hat eine begrenzte Content Security Policy.
- PCC ist eine optionale Runtime-Capability. Eine produktive Freigabe, Signierung oder App-Store-Abnahme ist mit dieser Projektgrundlage noch nicht belegt.

Physische Geräte, VoiceOver, iPad-Mehrfenster, alle Tastaturformen und Langzeitlast müssen separat praktisch abgenommen werden. Ein Build oder ein Session-Test ersetzt diese Nachweise nicht.
