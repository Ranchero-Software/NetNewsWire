# ReaderPersistence

Lokaler SwiftData-Speicher für den neuen Reader ab OS 27. `ReaderStore(url:inMemory:)` implementiert `ReaderRepository`. Ein Actor besitzt den erst innerhalb des Actors erzeugten `ModelContext`; ausschließlich `Sendable`-Snapshots verlassen den Speicher. CloudKit ist ausdrücklich deaktiviert.

Die App muss für Debug und Release unterschiedliche Store-URLs bereitstellen. Tests verwenden `inMemory: true` oder einen eigenen temporären Store. Es werden keine NetNewsWire-Datenbanken geöffnet oder migriert.

Importierte OPML-Homepageadressen liegen in lokalen Feed-Einstellungen. `feeds()` ergänzt damit ausschließlich fehlende Servermetadaten; eine von FreshRSS gelieferte Homepageadresse hat Vorrang. Der ursprüngliche importierte Ordnerpfad bleibt ebenfalls in diesen lokalen Einstellungen gespeichert.

`mergeImportMetadata(feed:homePageURL:folderPath:feedURL:)` liest und schreibt diese Importmetadaten in einer einzigen Actor-Transaktion. Modus, Cloudfreigabe und Zeitzone werden aus dem aktuellen Zustand erhalten. Bereits bekannte Import-URLs werden nicht überschrieben; ein nichtleerer neuer Ordnerpfad wird übernommen, ein leerer Pfad löscht keine vorhandene Hierarchie.

`applyRefresh` setzt einen vollständig erfolgreichen Abruf aller erforderlichen FreshRSS-Status-/Abonnementseiten voraus. Feeds, Ordner und Statuslisten sind autoritativ, Artikelzulieferungen inkrementell. Fehlende Artikel einer Zulieferung werden nicht als Löschauftrag interpretiert. Bei doppelten Artikel-IDs gewinnt die letzte vollständige Version in Antwortreihenfolge; die erste Eingangszeit bleibt stabil. Ausstehende lokale Statusänderungen haben Vorrang vor Remoteantworten.

Status und Outbox werden gemeinsam gespeichert. Bestätigungen entfernen ausschließlich die gesendete UUID-Revision. Fehler rollen alle Änderungen einer Operation zurück. Abbestellen entfernt nur unmarkierte Artikel ohne Pendingauftrag oder Tagesübersichtsreferenz; markierte Originale bleiben in der globalen Sternansicht erhalten. Automatische altersabhängige Artikelbereinigung ist noch nicht implementiert.

`updateContent` speichert lokal extrahierten Volltext. Ein erneuter Refresh mit identischem Feedinhalt erhält diesen Cache. Ändert sich der ursprüngliche Feedinhalt oder die Originaladresse, wird der alte Volltext verworfen, damit eine neue Extraktion nicht durch veraltete Inhalte unterdrückt wird.

Produktive Extraktionsaufträge verwenden `updateContent(_:html:text:)` mit dem ursprünglichen `ArticleSnapshot`. Der atomare Vergleich verwirft verspätete Ergebnisse nach Änderungen von Titel, Inhalt, Feed oder URL. `saveDigest(_:expectedSources:)` übernimmt eine generierte Tagesübersicht nur, wenn sämtliche Quellenfassungen und der vollständige aktuelle Quellensatz ihres Eingangstags noch passen. Lesestatusänderungen allein machen diese Inhaltsaufträge nicht ungültig. Ein veralteter Auftrag liefert `false` ohne Schreibereignis.

Lokale Suche normalisiert Titel und Text und filtert im Store; Ergebnisse sind auf höchstens 1.000 pro Seite begrenzt. Es handelt sich um Teilstringsuche ohne Relevanzranking. Die Reihenfolge ist Eingang absteigend, danach stabile Identität. Ordnerabfragen benötigen eine ausdrückliche Konto-ID und berücksichtigen ausschließlich die Feedmitgliedschaften dieses Kontos; leere Ordner liefern eine leere Artikelliste.

`article(_:)` lädt eine einzelne kontoabhängige Identität direkt, unabhängig von der sichtbaren Seite. `changes()` liefert einen gepufferten Revisionsstream mit aktuellem Anfangswert und einer neuen Revision nach jedem erfolgreichen Schreibvorgang. Mehrere Fenster können dieselben Änderungen beobachten; die Beendigung einer Beobachtung hält den Store nicht im Besitzkreis. Fehlgeschlagene Operationen veröffentlichen keine erfolgreiche Revision.

Prüfung: `swift test --package-path ReaderKit --filter ReaderStoreTests`. Die Swift-Testing-Suite deckt verspätete Bestätigungen, Pendingstatus, kanonische Versionen, leere Ordner, Retention, Rollback, Suche und erneutes Öffnen eines Dateistores ab. Reale FreshRSS-Mehrgerätetests und ein echter App-Neustart sind getrennte Integrationsabnahmen.
