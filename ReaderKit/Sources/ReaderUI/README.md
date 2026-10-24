# ReaderUI

Gemeinsame SwiftUI-Oberfläche ab macOS, iOS und iPadOS 27. Jede `ReaderWindow` besitzt eine eigene `ReaderSession` mit Auswahl, Suche, Präsentationen und Abfragegeneration. Ausschließlich Datenhaltung, FreshRSS und Inhalts-/KI-Dienste werden über `ReaderServices` geteilt.

Die Oberfläche zeigt normale Artikel und Tagesübersichten. Suche, Sterne und die Feedansicht erschließen Originale. Fehlende oder fehlgeschlagene Zusammenfassungen verstecken keine unverarbeiteten Beiträge. Öffnen verändert keinen Lesestatus; „Übersicht gelesen“ verwendet die Quellen der angezeigten Revision.

Die Liste fragt in Seiten bis zu 200 Artikeln ab. Bereits gebündelte Originale werden beim Einsammeln verworfen; weitere Rohseiten werden geladen, bis die gewünschte Zahl sichtbarer Einzelartikel erreicht oder der Bestand erschöpft ist. Ein großer Dealfeed kann dadurch normale Feeds nicht aus der ersten sichtbaren Seite verdrängen. Quellen und ausgewählte Artikel werden über ihre kontoabhängige Identität nachgeladen. Die Fußzeile weist ausdrücklich die Zahl geladener Originale aus. Ein Store-Änderungsstream invalidiert andere Fenster. UI-Zustand wird auf dem MainActor verwaltet; I/O liegt bei den Diensten.

Beim Aktivieren einer Szene wird FreshRSS aktualisiert. Gleichzeitige Fenster teilen denselben besessenen Auftrag; innerhalb von 60 Sekunden nach erfolgreicher Aktualisierung wird automatisch kein zweiter gestartet. Manuelles Aktualisieren erzwingt einen neuen Abgleich. Die Absage eines Fenster-Tasks beendet keine bereits geteilte Kontoarbeit. Auf dem iPhone startet die Navigation in der Sidebar, sodass die Verbindungseinrichtung unmittelbar erreichbar ist.

`ReaderSessionTests` verwendet Swift Testing mit isolierten In-Memory-Stores. `ReaderSmokeTests` bleibt gemäß `modernize-tests` bei XCTest/XCUIAutomation. Die separate App wird über `Reader.xcodeproj` gebaut; `python3 ReaderApp/generate_project.py` regeneriert das Projekt einschließlich aller aktuellen Pakettests.

Keine UIKit-Controller des alten Readers werden eingebunden. UIKit/AppKit-Geometrie oder globale Szenensuche werden im neuen Pfad nicht verwendet. Tatsächliche Abnahme von VoiceOver, Tastaturen, mehreren iPad-Fenstern und physischen Geräten bleibt getrennt zu dokumentieren. Der lokale Mac-UI-Runner meldete bei der Abnahme `AXIsProcessTrusted=false` und `kAXErrorAPIDisabled` (-25211), während die App sichtbar gerendert wurde. Eine gültige Signatur ersetzt diese Bedienungshilfenfreigabe nicht; diese interaktive Mac-Abnahme ist daher offen.
