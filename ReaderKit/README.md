# Reader

Eigenständiger FreshRSS-Reader für macOS, iOS und iPadOS **ab Version 27**. Die gemeinsame SwiftUI-App liegt in `ReaderApp/`, ihr Xcode-Projekt ist `Reader.xcodeproj`. Dieser neue Pfad übernimmt keine alten NetNewsWire-Datenbanken, Controller, Kontoanbieter oder direkten RSS-/Atom-Parser. Die bisherigen Targets bleiben während der Abnahme erhalten.

## Starten

`Reader.xcodeproj` in Xcode 27 öffnen und die Scheme **Reader** wählen. Für ein Gerät ist eine eigene Development-Team-Konfiguration nötig. Debug verwendet `eu.mpwg.reader.debug`, Release `eu.mpwg.reader`. Datenspeicher und Keychain-Dienst werden aus der jeweiligen Bundle-ID abgeleitet. Die App benötigt keine privaten NetNewsWire-API-Schlüssel.

In FreshRSS den API-Zugriff aktivieren und ein **API-Passwort** festlegen. In Reader die FreshRSS-Installationsadresse oder die vollständige Adresse `…/api/greader.php`, den Benutzernamen und das API-Passwort eingeben. Die Anmeldung verwendet die Google-Reader-kompatible API, kein interaktives Browser-/OIDC-Login. Die Kontooberfläche akzeptiert HTTPS.

Bereits geladene Artikel bleiben ohne Netzwerk lesbar. Lesestatus und Sterne werden zuerst lokal samt versioniertem Sendeauftrag gespeichert und beim nächsten erfolgreichen Sync übertragen. Ein Refresh gilt erst nach vollständigem Abruf und Speicherung als erfolgreich. Beim Aktivieren eines Fensters aktualisiert ein gemeinsam koordinierter Dienst; manuelles Aktualisieren bleibt möglich.

## Tagesübersichten

Im Kontextmenü eines Feeds **Feed-Einstellungen** öffnen und **Tagesübersicht** wählen. Je Eingangstag entsteht eine Karte mit gespeicherter Zeitzone, thematischen Abschnitten und Originalquellen. Weitere Beiträge aktualisieren diese Karte. Suche, Sterne und die Feedansicht erschließen die einzelnen Artikel. Fehlende Zusammenfassungen verstecken keine unbearbeiteten Originale.

Das Öffnen verändert den Lesestatus nicht. **Übersicht gelesen** markiert genau die Quellen der angezeigten Revision; spätere Beiträge bleiben ungelesen. Die Fußzeile unterscheidet sichtbare Einträge und geladene Originale. Bei mehreren Fenstern bleiben Auswahl, Suche und Dialoge unabhängig.

Die lokale Foundation-Models-Inferenz ist der Standard. Bei kurzen Feedtexten lädt die App die Originalseite nach und extrahiert den Volltext **lokal**, ohne den privaten Feedbin-Extraktionsdienst. Websiteabrufe kontaktieren die jeweilige Website. Seitenskripte werden bei der Extraktion nicht ausgeführt. Quelle, Abbruch und Version werden vor dem Speichern geprüft. HTTP-Fehler, fehlendes Modell und nicht zusammengefasste Beiträge werden angezeigt.

**PCC ist im normalen Build deaktiviert.** Apples API kann trotz positiver Verfügbarkeitsmeldung bei fehlendem `com.apple.developer.private-cloud-compute`-Entitlement den Prozess beenden. Vor Aktivierung sind Apples Freigabe, passende Provisionierung/Signierung und eine getrennte App-Abnahme erforderlich. Erst dann darf die Bootstrap-Konfiguration `AppleSummaryGenerator(privateCloudComputeEnabled: true)` und `ReaderServices(privateCloudComputeConfigured: true)` verwenden. Jede Cloudanfrage prüft zusätzlich die aktuelle Feedfreigabe. Eine bereits laufende Übertragung lässt sich durch nachträglichen Widerruf nicht rückgängig machen. Es gibt keine Drittanbieter-KI-Anbindung.

KI-Ergebnisse und Feedmodus bleiben pro Gerät; nur FreshRSS-Abonnements und Originalstatus synchronisieren geräteübergreifend. Widgets, Erweiterungen, AppleScript, Theme-Import und weitere Anbieter gehören nicht zu dieser Version.

## OPML

Import und Export erfolgen über das Reader-Menü. FreshRSS besitzt flache Kategorien: importierte Pfade wie `A/News` und `B/News` werden als unterschiedliche Kategorien angelegt und lokal für einen verschachtelten OPML-Roundtrip erhalten. Homepage-URLs bleiben als lokaler Fallback verfügbar; aktuelle Servermetadaten haben Vorrang. Identische Wiederholungsimporte werden koalesziert. Ein Feed in widersprüchlichen OPML-Pfaden wird vor Serveränderungen abgelehnt, weil FreshRSS pro Feed eine Kategorie unterstützt.

## Architektur und Tests

`ReaderDomain` enthält Sendable-Snapshots und Schnittstellen. `ReaderPersistence` besitzt SwiftData-Kontexte und atomare Schreibverträge. `ReaderSync` besitzt FreshRSS, Keychain, OPML-Import und den begrenzten Icon-Dienst. `ReaderContent` verarbeitet HTML/OPML; `ReaderIntelligence` besitzt Modell- und Digestaufträge. `ReaderUI` enthält gemeinsame Views und szenenbezogenen Zustand. Die Oberfläche verwendet zunächst Systemsymbole für Feeds.

Fachtests verwenden Swift Testing mit isolierten Stores und Netzwerkskripten; UI-Tests bleiben XCTest/XCUIAutomation. Tests benötigen keine persönlichen Zugangsdaten und starten keine KI-Anfragen.

```sh
swift test --package-path ReaderKit
python3 -m unittest discover -s scripts/tests -v
bash scripts/test-reader.sh all
```

Der native Runner baut zuerst mit lokaler Ad-hoc-Signatur und prüft auf dem Mac App und Testrunner vor deren Start. Die Auswahl `macos`, `ios` oder `ipad` prüft eine einzelne Plattform. Ergebnisse liegen in einem neu erzeugten temporären Verzeichnis oder unter `READER_RESULTS_DIR`. Fehler dürfen keine Gesamterfolgsmeldung erzeugen. GitHub verwendet das dokumentierte `xcode-27`-Runnerimage; die tatsächlichen CI-Läufe sind gesondert zu prüfen.

`python3 ReaderApp/generate_project.py` regeneriert deterministisch das Projekt und nimmt alle aktuellen Tests auf. Testplan und Projekt gehören ins Repository. Details zum überprüften Stand und zu offenen Prüfungen stehen in [der Abnahmematrix](../docs/reader/acceptance.md).

## Herkunft

Die lokale Volltextextraktion verwendet Mozillas Readability und JSDOMParser, fixiert auf Commit `ab4027a8b37669745016869a37a504727992b2ba`. Die unveränderten Quelldateien und Apache-2.0-Lizenz liegen unter `Sources/ReaderContent/Resources/`; die URL-Auflösung ergänzt die App über Foundation. Die MIT-Lizenz und Copyright-Hinweise von NetNewsWire bleiben erhalten.

Plan und Fortschritt: [Dachissue #45](https://github.com/mpwg/NetNewsWire/issues/45), Arbeitspakete #46–#56. Ein implementierter oder gebauter Pfad ist noch keine vollständige Geräte-, Dienst- oder Qualitätsabnahme.
