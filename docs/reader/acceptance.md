# Reader: Abnahmestand 24.10.2026

Der Umbau ist **implementiert, aber nicht vollständig abgenommen**. Die laufende Arbeit wurde auf Wunsch des Auftraggebers geordnet beendet. Verbindliche Planung: [#45](https://github.com/mpwg/NetNewsWire/issues/45), Arbeitspakete #46–#56. Die nachstehenden Nachweise beziehen sich auf den neuen Reader; die ursprünglichen NetNewsWire-Targets wurden in diesem Umsetzungslauf nicht erneut abgenommen.

## Aktuelle automatisierte Nachweise

Umgebung: MacBook Pro arm64, macOS 27.0.1, Xcode 27.1 (27A9275). Die finalen Xcode-Testpläne enthalten **78 unterschiedliche Fachtests** in zehn Suiten. Zwei parametrisierte Tests ergeben zusammen acht Parameterausführungen, also 84 Fachtestausführungen pro Plattform.

| Prüfung | Status | Beleg und Grenze |
|---|---|---|
| macOS Fachtests | erfüllt | 78 Tests / 84 Ausführungen, 0 Fehler. `/tmp/reader-final-verification-mac.xcresult`; ausschließlich `ReaderContractTests` ausgewählt. |
| iPhone-Simulator | erfüllt | iPhone Duo, iOS 27.1: 78 Fachtests plus ein nativer Anmeldeformular-/Abbrechen-Test; 79 Tests / 85 Ausführungen, 0 Fehler, 0 übersprungen. `/tmp/reader-final-verification-ios/ios.xcresult`. Zuvor auch iPhone 17 / iOS 27.0 erfolgreich. |
| iPad-Simulator | erfüllt | iPad Pro 13 Zoll (M5), iOS 27.0: 78 Fachtests plus derselbe native UI-Test; 79 Tests / 85 Ausführungen, 0 Fehler, 0 übersprungen. `/tmp/reader-final-verification-ipad/ipad.xcresult`. |
| macOS native UI-Automation | nicht prüfbar | App sichtbar; Runner gültig Ad-hoc-signiert. Fensterabfrage liefert `AXIsProcessTrusted=false` und `kAXErrorAPIDisabled` (-25211). Die beiden UI-Tests scheitern daran, wurden nicht durch Skips ersetzt. Nach Freigabe erneut ausführen. |
| Releasebuilds und Namespace | erfüllt | macOS und generischer iOS-Simulator bauen; expandierte Release-ID jeweils `eu.mpwg.reader`, Mindestversion jeweils 27.0. Debug-ID `eu.mpwg.reader.debug`, Store/Keychain-Dienst davon abgeleitet. |
| Vollständiger lokaler Testrunner | erfüllt | `scripts/test-reader.sh ios` und `ipad` tatsächlich erfolgreich. Zwei Python-Vertragstests belegen alle drei Plattformaufrufe und Fehlerweitergabe ohne falsche Erfolgsmeldung. |
| SwiftLint | erfüllt | SwiftLint 0.65.1, gesamtes Repository mit `--strict`: keine Befunde. Die Testkonfiguration erlaubt Satznamen gemäß `modernize-tests`. |
| GitHub CI | offen | [Lauf 40113981641](https://github.com/mpwg/NetNewsWire/actions/runs/40113981641) startet nach korrigiertem Workflow alle drei Plattformjobs, scheitert aber beim Kompilieren des Testfixtures `ReaderKit/Tests/ReaderSyncTests/IconServiceTests.swift:156`: `passing closure as a 'sending' parameter risks causing data races`. Lokal kompiliert derselbe Stand. Diese Toolchain-/Fixture-Abweichung ist der erste Fortsetzungspunkt in #46. Die vorherige unzulässige `runner`-Kontextverwendung im Job-`env` ist separat korrigiert und mit Actionlint 1.7.12 geprüft (dokumentiertes Previewlabel aus der älteren Labelliste ausgenommen). Kein gehosteter Erfolg behauptet. |

Der anfangs ungültig signierte `ReaderSmokeTests-Runner` wurde korrigiert. `codesign --verify --deep --strict` bestätigt die aktuellen Mac-Testartefakte. Es wurden keine Gatekeeper-, Accessibility- oder anderen globalen Schutz-/Rechteeinstellungen geändert. Swift-Compilerwarnings wurden beseitigt; Apple-Werkzeuge melden weiterhin übersprungene App-Intents-Metadatenextraktion ohne entsprechende Frameworkabhängigkeit und teils SDK-Buildnummer-Diagnosen.

Temporäre Logs/Resultbundles sind lokale Belege und können durch Betriebssystembereinigung verschwinden. Reproduzierbare Quellen, Fixtures und Befehle liegen im Repository; die Ergebniszusammenfassung wird in den GitHub-Arbeitspaketen weitergeführt.

## Kriterien nach Arbeitspaket

| Paket | Erfüllt | Offen / nicht prüfbar |
|---|---|---|
| A / #46 | Eigenständige OS-27-App, Namespace, eigener Store, gemeinsame Tests, sichere lokale Testsignierung, Fehlerweitergabe | Erfolgreichen gehosteten CI-Lauf und reguläre Geräteprovisionierung separat prüfen. |
| B / #47 | 24 Persistenztests: Wiederöffnen eines dauerhaften Stores, kanonische Artikelversion, versionierte Outbox, Rollback, Pending-Schutz, Sterne, Ordner-/Kontoabgrenzung, Änderungsstream, atomare Quellen-/Importprüfung | App-Neustart/Recovery mit produktionsnaher Datenmenge zusätzlich prüfen; keine alten Datenbanken importieren. |
| C / #48 | FreshRSS-HTTP-/Store-Verträge: vollständige Pagination, alte Veröffentlichungen, exakte Bestätigungen, Fehlerweitergabe, leere Ordner, Inhaltvollständigkeit | Echter FreshRSS-Server, echte API-Anmeldung, Mehrgeräteabgleich und Offline-Wiederanlauf wurden nicht mit persönlichen Konten ausgeführt. |
| D / #49 | Gemeinsame Views, asynchrone Suche/Pagination, Generationenprüfung, Quellzugriff, unverdrängte normale Artikel, eingefrorene Digestrevision | Vollständige native Bedienung mit echten Feedinhalten und Tastatur prüfen. |
| E / #50 | Szenenbezogener Zustand, gemeinsam besessene/debouncte Aktualisierung, keine globalen Screen-/Szenenadapter im neuen Pfad | Mac-AX-Freigabe; native Mehrfenster-, Größen-, RTL-, Tastatur-, VoiceOver- und Dynamic-Type-Abnahme. |
| F / #51 | Neun Content-/OPML-Tests: lokale Extraktion ohne Seitenskripte, relative Links, HTTP 403, Timeout, neue URL-Inhaltsversion, Größenlimit; atomare Stale-Write-Abweisung | Reale blockierte Seiten, HTML-/Medienvarianten und Readeransicht auf den Geräten prüfen. |
| G / #52 | Gerätelokaler Keychain-Dienst, begrenzte Iconaufträge, unabhängiger Fallback, temporärer Retry und Abbruch; Tests in ReaderSync | Echte Keychain-Anmeldung sowie reale Energie-/Bildlast prüfen. Die UI verwendet zunächst Systemsymbole für Feeds. |
| H / #53 | Parser-/Export- und API-/SwiftData-Integration für verschachtelte Ordner, Homepage, Redirect-Wiederholung und atomaren Präferenzerhalt | Gegen echten FreshRSS bestätigen. Kategorien sind dort flach; Hierarchie wird zusätzlich lokal erhalten. |
| I / #54 | Lokale Foundation-Models-Inferenz im echten Mac-Framework mit zwei synthetischen Angebotsquellen mehrfach erfolgreich; dynamisches Budget, strukturierte Quellen, aktuelle Cloudfreigabe | PCC-Freigabe/Provisionierung und Native-App-PCC-Abnahme fehlen. Breite Qualitäts-/Sprach-/Langtextabnahme bleibt offen. |
| J / #55 | Sieben Digesttests: 250 Quellen, Tagesbündelung, unvollständige KI, alte angezeigte Revision, Quelländerung, Widerruf und fensterunabhängiger Auftragsbesitz | Tatsächlichen Preisjäger-Feed und repräsentative Nachrichtenqualität einschließlich Fehler-/Modellvarianten abnehmen. |
| K / #56 | Zuordnung aller 40 Auditbefunde, geprüfter neuer Abhängigkeitsgraph, dokumentierter Bestand | Vollständige Produktabnahme und erst danach Legacy-Entfernung. Physische Geräte, VoiceOver, Dynamic Type, Langzeit-/Energieverhalten, Distribution sind nicht abgenommen. |

## Ergänzende Experimente

- Lokale KI: drei wiederholte Aufrufe mit zwei synthetischen Angeboten ergaben jeweils zwei belegte Abschnitte, korrekte Händler und Preise sowie beide Quellen. Gemessene Inferenz etwa 1,6–1,7 Sekunden. Das ist ein kleiner Funktionsnachweis, keine systematische Qualitätsgarantie.
- PCC: Eine isolierte synthetische Entwicklerprobe meldete zunächst `available`, beendete den Prozess beim Request aber wegen fehlendem `com.apple.developer.private-cloud-compute`. Daher sperrt der normale Build diesen Aufruf **vor** der API-Anfrage; der Cloudschalter ist ohne konfigurierte Freigabe deaktiviert. Diese Sperre ist keine erteilte PCC-Berechtigung.
- SwiftData-Lastprobe mit 10.000 synthetischen Artikeln auf diesem Mac: Einfügen 0,82 s, erste 200 Artikel 0,006 s, normalisierte Suche 0,007 s, 1.000 Statusänderungen 1,97 s. Kein Vergleich mit Legacy und kein Scroll-/Energie- oder Gerätelastnachweis.

## Audit-Issues und nächste Abnahme

21 nicht übernommene Befunde wurden auf ausdrücklichen Nutzerauftrag als **nicht geplant** geschlossen: #2, #3, #4, #6, #7, #8, #9, #11, #13, #14, #18, #19, #20, #23, #24, #27, #28, #31, #32, #35, #36. Das ist keine Reparatur oder bereits erfolgte Entfernung ihrer alten Codepfade.

Der ersetzte Migrationsvorschlag #42 ist ebenfalls als nicht geplant geschlossen. #43 und #44 sind als fertig erstellte Berichte abgeschlossen. 19 weiterhin relevante Befund-Issues bleiben offen und sind den neuen Paketen zugeordnet. Die elf Umsetzungspakete bleiben bis zur kriteriumsgerechten Abnahme offen; Implementierungs- und Testfortschritt wird dort getrennt ausgewiesen.

Die nächste Arbeit beginnt mit dem [Handoff](handoff-2026-10-24.md), nicht mit einem weiteren parallelen Neubau.
