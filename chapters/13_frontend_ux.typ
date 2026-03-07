#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Karun Sandhu")

= User Interface & Visualisierung <frontend_ux>

Die Benutzeroberfläche von #htl3r.long[diagnet] deckt alle Kernfunktionen der Plattform ab: Geräteverwaltung, Testfall-Erstellung und -Ausführung, Ergebnisvisualisierung, Gruppierung sowie Benutzer- und Rechteverwaltung. Das gesamte Frontend basiert auf serverseitigem Rendering nach dem #htl3r.short[mvt]-Muster und wird durch #htl3r.long[bootstrap] 5.3 und #htl3r.long[htmx] 2.0 ergänzt, um Responsivität und partielle Seitenaktualisierungen ohne eigenes JavaScript-Framework zu ermöglichen. Die Visualisierung der Testergebnisse im Dashboard ist in @data_visualization beschrieben.

== Frontend-Technologien <frontend_technologien>

Die Wahl der Frontend-Technologien folgt direkt aus der Architekturentscheidung für das Django-Framework, die in @django_framework begründet wurde. Da Django nach dem #htl3r.full[mvt]-Muster arbeitet, übernimmt der Server die vollständige Generierung der #htl3r.short[html]-Ausgabe. Das bedeutet: Jede Seite wird serverseitig gerendert und als fertiges Dokument an den Browser ausgeliefert. Clientseitige JavaScript-Frameworks wie React oder Vue, die eine separate Rendering-Logik im Browser betreiben, hätten dieses Prinzip durchbrochen und eine eigenständige #htl3r.full[api] zwischen Frontend und Backend erfordert, was für #htl3r.long[diagnet] nicht gerechtfertigt war.

=== Bootstrap

Für das visuelle Erscheinungsbild und die Responsivität der Oberfläche kommt #htl3r.long[bootstrap] 5.3 zum Einsatz. #htl3r.long[bootstrap] ist ein komponentenbasiertes #htl3r.full[css]-Framework, das ein umfangreiches Grid-System sowie vorgefertigte UI-Komponenten wie Navigationsleisten, Karten, Modale, Tabellen und Badges mitliefert @bootstrap-docs.

Außerdem unterstützt #htl3r.long[bootstrap] einen Dark Mode über das `data-bs-theme`-Attribut, das beim Seitenaufruf automatisch aus dem `localStorage` gesetzt wird. Da die Diagramme ihre Farben aus #htl3r.long[bootstrap]-#htl3r.short[css]-Variablen beziehen, reagieren sie auf Theme-Wechsel ohne Neuinitialisierung. Dafür überwacht ein `MutationObserver` das Attribut und ruft bei einer Änderung die Aktualisierungsfunktion aller Chart-Instanzen auf.

=== HTMX

Die interaktivsten Teile der Oberfläche, also Gerätelisten, Testausführung, Modal-Formulare und Statusaktualisierungen, erfordern asynchrone Kommunikation mit dem Server, ohne dabei die gesamte Seite neu zu laden. Hierfür wird #htl3r.long[htmx] 2.0 eingesetzt. #htl3r.long[htmx] erlaubt es, #htl3r.short[http]-Requests direkt aus #htl3r.short[html]-Attributen heraus zu steuern und die Antwort des Servers gezielt in bestimmte DOM-Bereiche einzufügen @htmx-docs.

#htl3r.code(
  caption: [HTMX-Attribute für die lazy-geladene Gerätetabelle],
  description: `devices/index.html`,
)[
  ```html
  <div hx-get="/devices/table/"
       hx-trigger="load, refresh from:body"
       hx-swap="innerHTML"
       id="device-table">
    <!-- Skeleton wird angezeigt bis der Inhalt geladen ist -->
  </div>
  ```
]

In diesem Beispiel löst das Attribut `hx-trigger="load"` beim Seitenaufruf automatisch einen `GET`-Request aus, der den Tabelleninhalt nachlädt. Der zusätzliche Trigger `refresh from:body` ermöglicht es, die Tabelle von beliebigen anderen Stellen der Seite aus per `htmx.trigger(document.body, 'refresh')` zu aktualisieren, beispielsweise nachdem ein Gerät erstellt, bearbeitet oder gelöscht wurde. Der Server liefert in diesem Fall kein vollständiges HTML-Dokument zurück, sondern nur das Fragment, das in den Ziel-Container eingefügt werden soll.

Während #htl3r.long[htmx]-Requests laufen, werden Skeleton-Platzhalter angezeigt, die die spätere Tabellenstruktur bereits andeuten und ein Layout-Springen beim Laden verhindern. Für Schreiboperationen (`POST`, `DELETE`) werden die #htl3r.short[csrf]-Token über den `hx-headers`-Parameter mitgeliefert, da Django #htl3r.short[csrf]-Schutz für alle zustandsverändernden Requests erzwingt. Serverseitige Rückmeldungen werden nicht als Teil des HTML-Fragments, sondern über den `HX-Trigger`-Response-Header als benutzerdefinierte Events übermittelt. Das `showMessage`-Event fängt ein globaler Event-Listener ab und zeigt daraufhin einen #htl3r.long[bootstrap]-Toast an. Dieses Pattern ersetzt ein #htl3r.short[spa]-Framework vollständig: Routing, State-Management und eine separate Build-Pipeline entfallen, da #htl3r.long[diagnet] auf Djangos Session-System und serverseitiges Rendering aufbaut.

== Geräteverwaltung <frontend_geraeteverwaltung>

Die Geräteverwaltung unter `/devices/` bildet die Grundlage für alle testbezogenen Operationen, da Testfälle immer an konkrete Geräte gebunden sind. Die Seite listet alle erfassten Netzwerkgeräte tabellarisch auf, wobei die Tabelle per #htl3r.long[htmx] lazy geladen wird. Berechtigungsabhängig werden zusätzliche Aktionsschaltflächen eingeblendet, etwa für das Anlegen oder Bearbeiten von Geräten.

=== Geräteliste mit Live-Statusanzeige

Jede Zeile der Gerätetabelle enthält neben Name, IP-Adresse, Port, Protokoll und Gerättyp eine Statusspalte, die den aktuellen Verbindungsstatus des Geräts anzeigt. Dieser Status wird nicht beim Seitenaufruf automatisch geprüft, da ein simultaner Verbindungstest aller Geräte die Ladezeit massiv erhöhen würde. Stattdessen gibt es pro Zeile eine "Check Status"-Schaltfläche, die per #htl3r.long[htmx] einen `GET`-Request an `/devices/<pk>/check/` sendet und das Ergebnis direkt in die Statusspalte der betreffenden Zeile schreibt.

Zusätzlich steht eine "Check All Devices"-Schaltfläche zur Verfügung, die einen `POST`-Request an einen dedizierten `/devices/check-all/`-Endpunkt sendet. Der Server prüft dort alle Geräte parallel über einen `ThreadPoolExecutor`, sodass alle Verbindungstests gleichzeitig ablaufen. Das Ergebnis wird als Toast-Nachricht mit der Anzahl erreichbarer und nicht erreichbarer Geräte zurückgemeldet. Während der Request läuft, ist die Schaltfläche deaktiviert und zeigt einen Spinner, um Doppelklicks zu verhindern.

#figure(
  image("../assets/screenshot_device_list.png", width: 100%),
  caption: [Geräteliste mit Verbindungsstatus und Aktionsschaltflächen],
) <screenshot_device_list>

=== Hinzufügen und Bearbeiten via Modal

Das Anlegen und Bearbeiten von Geräten erfolgt in einem #htl3r.long[bootstrap]-Modal, das bei Klick auf "Add Device" bzw. "Edit" dynamisch mit dem jeweiligen Formular befüllt wird. Beim Öffnen des Modals wird das Formular per #htl3r.long[htmx] frisch vom Server geladen, was sicherstellt, dass bei einem erneuten Öffnen keine Überreste aus dem vorherigen Aufruf im #htl3r.short[dom] verbleiben. Nach erfolgreicher Speicherung sendet der Server den HTTP-Status `204 No Content` zurück, was clientseitig das Modal schließt und die Gerätetabelle über das `devicesRefresh`-Event aktualisiert.

Das Löschen eines Geräts wird direkt aus der Tabelle heraus mit einem `DELETE`-Request per #htl3r.long[htmx] ausgelöst, wobei ein nativer Browser-Bestätigungsdialog (`hx-confirm`) dem Anwender eine letzte Sicherheitsabfrage stellt.

#figure(
  image("../assets/screenshot_device_modal.png", width: 80%),
  caption: [Modal zum Anlegen eines neuen Geräts],
) <screenshot_device_modal>


== Testverwaltung <frontend_testverwaltung>

Die Testverwaltung gliedert sich in die Testfall-Liste mit Detailansicht und Ausführungsfunktion sowie die Testgruppen-Verwaltung im Dashboard. Das Erstellen neuer Testfälle über das dynamische Formular ist in @dynamic_forms beschrieben.

=== Testfall-Liste und Testdetails

Unter `/tests/` werden alle angelegten Testfälle tabellarisch aufgeführt, jeweils mit Label, zugehörigem Testmodul und dem Ergebnis des letzten Testlaufs. Ein Klick auf einen Testfall öffnet die Detailansicht als Modal, das per HTMX lazy geladen wird. Das Modal gliedert sich in zwei Bereiche: Der obere Teil zeigt einen PASS/FAIL/NEW-Badge mit dem Zeitstempel des letzten Laufs, die konfigurierten Eingabeparameter als zweispaltige Tabelle sowie die zugewiesenen Geräte mit ihrer jeweiligen Rolle. Der untere Bereich enthält eine paginierte Ausführungshistorie, in der jede Zeile die Versuchsnummer (`attempt_id`), Zeitstempel und Pass/Fail-Status ausweist. Ein Klick auf eine Zeile klappt ein Accordion auf, das die einzelnen Testmodule des jeweiligen Laufs mit Modulname, Ergebnis, Meldung und Laufzeit auflistet. Dabei kann jeweils nur ein Accordion gleichzeitig offen sein.

Die Ausführung eines Testfalls erfolgt per "Run"-Button direkt aus der Liste, der einen `POST`-Request an `/tests/<pk>/run/` sendet und das aktualisierte Ergebnis als Fragment zurückbekommt.

=== Testgruppen und Accordion-Ansicht

Die Gruppierung von Testfällen in Testgruppen ist eine zentrale Funktion von #htl3r.long[diagnet]. Die Testgruppen werden im Dashboard als #htl3r.long[bootstrap]-Accordion dargestellt: Jede Gruppe entspricht einem aufklappbaren Element, das beim Öffnen die zugehörigen Testfälle in einer Tabelle anzeigt. Jede Gruppe verfügt über Schaltflächen zum Ausführen aller enthaltenen Tests ("Run all tests"), zum Bearbeiten und Löschen der Gruppe.

Das Anlegen und Bearbeiten von Testgruppen folgt demselben Modal-Muster wie die Geräteverwaltung. Bei einer Bearbeitung wird nach dem Speichern nicht das gesamte Accordion neu gerendert, sondern nur das betroffene Accordion-Item per `HX-Retarget`- und `HX-Reswap`-Header gezielt ausgetauscht und dabei offen gelassen. Eine Neuerstellung der Gruppe hingegen erfordert ein vollständiges Refresh des Dashboard-Inhalts via `refreshDashboard`-Event, da das neue Item an die richtige Position im Accordion eingefügt werden muss.

#figure(
  image("../assets/screenshot_testgroup_accordion.png", width: 100%),
  caption: [Accordion-Ansicht mit aufgeklappter Testgruppe und Testergebnissen],
) <screenshot_testgroup_accordion>

== Benutzerverwaltung <frontend_benutzerverwaltung>

Die Benutzerverwaltung ist ausschließlich für Benutzer mit der Berechtigung `auth.view_user` zugänglich und gliedert sich in eine User-Liste sowie eine Gruppen-Liste. Beide Ansichten folgen dem in der Anwendung etablierten Modal-Pattern: Details, Bearbeitungsformulare und Bestätigungsdialoge werden per #htl3r.long[htmx] in Modals geladen, ohne die Seite neu aufzubauen.

=== Rollenmodell

#htl3r.long[diagnet] verwendet ein gruppenbasiertes Rollenmodell. Beim ersten Start der Anwendung werden automatisch vier Standardrollen angelegt:

#figure(
  table(
    columns: (auto, 1fr, auto),
    stroke: 0.5pt,
    fill: (col, row) => if row == 0 { luma(240) } else { white },
    align: (left, left, left),
    [*Rolle*], [*Berechtigungen*], [*Badge*],
    [Viewers],
    [Lesezugriff auf Geräte, Tests, Gruppen, Ergebnisse],
    [Read Only],

    [Editors], [Viewers + Erstellen und Bearbeiten], [View + Edit],
    [Managers], [Editors + Löschen], [Full CRUD],
    [Admins], [Managers + Benutzerverwaltung + Custom Templates], [Full Access],
  ),
  caption: [Vordefinierte Rollen und deren Berechtigungsumfang],
) <rollen_tabelle>

Die Standardrollen werden per `post_migrate`-Signal angelegt, sodass sie nach jeder Migration automatisch auf dem aktuellen Stand der Datenbankberechtigungen sind.

#figure(
  image("../assets/screenshot_user_list.png", width: 100%),
  caption: [Benutzerverwaltung mit Rollen-Badges und Aktionsschaltflächen],
) <screenshot_user_list>

=== User anlegen und bearbeiten

Das Anlegen und Bearbeiten von Benutzern folgt dem etablierten Modal-Pattern der Anwendung. Über separate Modals können Benutzerdaten, Gruppen-Zuordnungen und Passwörter bearbeitet werden. Eine Besonderheit: Das Löschen des eigenen Accounts wird serverseitig explizit verhindert, um ein versehentliches Aussperren aller Administratoren zu verhindern.

=== Permission-basiertes Template-Rendering

Die Sichtbarkeit von Schaltflächen und Aktionen ist in jedem Template direkt an Djangos Permission-System gekoppelt. Die Template-Tags `{% if perms.<app>.<action>_<model> %}` steuern, ob ein Element überhaupt im #htl3r.short[dom] erscheint. Dadurch werden sicherheitskritische Aktionen nicht nur serverseitig geschützt, sondern auch in der Oberfläche nicht angezeigt, wenn der Benutzer die notwendige Berechtigung nicht besitzt. Diese Trennung zwischen visueller Darstellung und serverseitiger Absicherung ist bewusst doppelt ausgeführt: Templates rendern nur, was der Benutzer sehen darf, serverseitige Views verweigern unabhängig davon jede unberechtigte Anfrage mit HTTP 403 @django-docs.

== Custom Test Templates <frontend_custom_templates>

Die Verwaltung benutzerdefinierter Testvorlagen unter `/tests/templates/manage/` ist ausschließlich Admins zugänglich. Custom Templates erweitern den Testfall-Katalog von #htl3r.long[diagnet] um selbst geschriebene Python-Klassen, die auf dem Server abgelegt und über die Oberfläche aktiviert werden. Da diese Klassen mit den vollen Rechten des Anwendungsprozesses ausgeführt werden, ist die Verwaltungsseite mit expliziten Sicherheitshinweisen versehen.

=== Sicherheitswarnung

Beim Aufruf der Seite wird unabhängig von der aktuellen Systemkonfiguration immer ein rot hinterlegter Warnhinweis angezeigt:

_"Custom test templates are Python scripts that execute with the same permissions as the application server. Only enable templates from trusted sources. Malicious templates can lead to Remote Code Execution (RCE) and full system compromise."_

Diese Warnung ist permanent sichtbar und kann nicht weggeklickt werden, um den ernsten Charakter der Funktion zu unterstreichen. Zusätzlich wird ein zweiter Hinweis angezeigt, wenn das Feature serverseitig über die Umgebungsvariable `DIAGNET_ENABLE_CUSTOM_TESTCASES` deaktiviert ist: In diesem Fall werden zwar Templates in der Tabelle gelistet und können aktiviert werden, sie werden aber beim Start der Anwendung nicht geladen, ein Verhalten, das im Hinweis explizit beschrieben wird.

#figure(
  image("../assets/screenshot_custom_templates_warning.png", width: 100%),
  caption: [Verwaltungsseite für Custom Templates mit permanenter Sicherheitswarnung],
) <screenshot_custom_templates>

=== Template-Tabelle und Sync

Die Tabelle listet alle bekannten Custom-Templates mit Klassenname, Dateiname, Status (aktiv/inaktiv) und dem Zeitpunkt der letzten Erkennung auf. Der Status kann per Toggle-Schaltfläche direkt in der Tabelle geändert werden; die Änderung wird per #htl3r.long[htmx] an `/tests/templates/toggle/<pk>/` übermittelt und die Tabelle anschließend mit dem aktualisierten Fragment ersetzt.

Der "Sync from Disk"-Button löst einen `POST`-Request an `/tests/templates/sync/` aus. Die Sync-Logik durchsucht das konfigurierte Verzeichnis nach Python-Dateien, prüft deren Gültigkeit und trägt neue Klassen in die Datenbank ein. Bereits bekannte, aber nicht mehr vorhandene Dateien werden aus der Datenbank entfernt. Das Ergebnis wird als Toast-Nachricht zurückgegeben: Anzahl neu entdeckter Templates oder eine Warnung bei Konflikten mit eingebauten Testklassen.
