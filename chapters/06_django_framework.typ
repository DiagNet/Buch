#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Karun Sandhu")
= Applikationsarchitektur des #box[Backends] <backend_architektur>

#htl3r.long[diagnet] verwaltet Netzwerkgeräte, Testfälle, Testergebnisse und Benutzerrechte. Diese Daten stehen nicht isoliert nebeneinander: Ein Testfall gehört zu einem Gerät, ein Ergebnis zu einem Testfall, eine Berechtigung zu einem Benutzer. Je mehr solcher Relationen eine Plattform abbilden muss, desto mehr bestimmt die Wahl des #htl3r.longpl[framework], wie viel davon selbst implementiert werden muss und wie viel von Haus aus mitgeliefert wird. Diese Entscheidung war der Ausgangspunkt für die Architektur des #htl3r.longpl[backend].

== Das Django Framework <django_framework>

Für die Entwicklung der zentralen Verwaltungsplattform von #htl3r.long[diagnet] fiel die Wahl auf das in Python geschriebene Web-#htl3r.long[framework] Django. Django folgt dem Prinzip "Batteries included" @django-docs: Authentifizierung, Session-Management und Schutzmechanismen gegen gängige Web-Vulnerabilitäten sind standardmäßig integriert, ohne dass externe Bibliotheken eingebunden werden müssen. Wie diese Mechanismen konkret zum Einsatz kommen, wird in @data_security behandelt.

Da #htl3r.long[diagnet] komplexe Relationen zwischen Netzwerkgeräten, Testfällen und historischen Testergebnissen abbilden muss, war Djangos integriertes #htl3r.full[orm] ein entscheidender Faktor. Statt rohe #htl3r.full[sql]-Zugriffe von Hand zu implementieren, lassen sich Datenbankoperationen direkt über Python-Objekte ausdrücken. Das resultierende Datenbankschema und die konkreten Modellentscheidungen sind in @data_modeling dokumentiert.

=== Alternativen und Entscheidungsfindung

Die Wahl des serverseitigen #htl3r.longpl[framework] wurde maßgeblich durch #htl3r.long[pyats] @pyats-docs beeinflusst. Da dieses Tool nativ auf Python basiert, war ein Python-#htl3r.long[backend] zwingend erforderlich. Um zwischen Django, Flask und FastAPI eine nachvollziehbare Entscheidung zu treffen, wurde eine Nutzwertanalyse durchgeführt.

Folgende vier Kriterien wurden für die Bewertung definiert:
- *Funktionsumfang:* Verfügbarkeit von "Out-of-the-Box"-Features wie #htl3r.short[orm] und Authentifizierung.
- *Tool-Integration:* Einbindung der nativen Python-Netzwerk-Bibliotheken.
- *Rendering:* Eignung für serverseitiges #htl3r.short[html]-Rendering.
- *#htl3r.short[api]-Fokus:* Ausrichtung auf reine Schnittstellen-Entwicklung.

==== Gegenüberstellung der Kriterien

Um die Relevanz der einzelnen Kriterien für das Projekt zu bestimmen, wurden diese im ersten Schritt paarweise miteinander verglichen. Das Kriterium, welches für #htl3r.long[diagnet] wichtiger ist, wurde in die jeweilige Zelle eingetragen.

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, center, center, center),
    stroke: 0.5pt,
    fill: (col, row) => if row == 0 or col == 0 { luma(240) } else { white },
    [], [*Tool-Integration*], [*Rendering*], [*#htl3r.short[api]-Fokus*],
    [*Funktionsumfang*],
    [Funktionsumfang],
    [Funktionsumfang],
    [Funktionsumfang],

    [*Tool-Integration*], [], [Tool-Integration], [Tool-Integration],
    [*Rendering*], [], [], [Rendering],
  ),
  caption: [Paarweiser Kriterienvergleich zur Ermittlung der Gewichtung],
) <kriterienvergleich>

Aus diesem Vergleich ergibt sich folgende Gewichtung (Anzahl der Nennungen):
- Funktionsumfang: 3
- Tool-Integration: 2
- Rendering: 1
- #htl3r.short[api]-Fokus: 0

#pagebreak()

==== Punktevergabe und Auswertung

Im zweiten Schritt wurden die #htl3r.longpl[framework] in den einzelnen Kategorien mit Punkten von 1 (sehr schlecht) bis 5 (sehr gut) bewertet. Das Kriterium "#htl3r.full[api]-Fokus" floss mit der Gewichtung 0 nicht in die finale Punktzahl ein, wurde der Vollständigkeit halber jedoch evaluiert.

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr, 1fr, auto),
    align: (left, center, center, center, center, right),
    stroke: 0.5pt,
    fill: (col, row) => if row == 0 { luma(240) } else { white },
    [*#htl3r.long[framework]*],
    [*Funktionsumfang (x3)*],
    [*Tool-Integration (x2)*],
    [*Rendering (x1)*],
    [*#htl3r.short[api]-Fokus (x0)*],
    [*Auswertung*],

    [Django], [5], [5], [5], [3], [$15 + 10 + 5 = 30$],
    [Flask], [2], [5], [3], [4], [$6 + 10 + 3 = 19$],
    [FastAPI], [2], [5], [2], [5], [$6 + 10 + 2 = 18$],
  ),
  caption: [Nutzwertanalyse und finale Auswertung der Frameworks],
) <nutzwertanalyse>

==== Entscheidung für Django

Django erreicht mit 30 Punkten den höchsten Wert. Den Ausschlag gibt der Funktionsumfang: Flask und FastAPI sind Micro-#htl3r.longpl[framework], die für eine vollständige Webanwendung mit Datenbank, Authentifizierung und serverseitigem Rendering auf externe Bibliotheken angewiesen sind. Django liefert diese Komponenten von Haus aus mit, was den Implementierungsaufwand für die Web-Infrastruktur deutlich reduzierte und den Fokus auf die Netzwerklogik ermöglichte.

=== Applikationsstruktur und Modularität

Das #htl3r.long[backend] von #htl3r.long[diagnet] ist in vier Django-Apps unterteilt, die jeweils einen klar abgegrenzten Verantwortungsbereich abdecken. `accounts` verwaltet Benutzerrollen, Berechtigungen und Authentifizierung. `dashboard` stellt die zentrale Übersichtsseite mit Metriken und Statusinformationen bereit. `devices` kapselt die gesamte Logik zur Geräteverwaltung: Verbindungsparameter, Zugangsdaten und die Schnittstellen zur Netzwerk-Engine. `networktests` verwaltet Testfälle, deren Parameter, die Ausführungshistorie sowie die Gruppierung von Tests zu Batches.

Durch die Abstraktion über das #htl3r.short[orm] kann die zugrunde liegende
Datenbank bei Bedarf von SQLite gegen PostgreSQL ausgetauscht werden, ohne dass
Datenmodelle oder Programmlogik angepasst werden müssen.

=== Model-View-Template (MVT) Architektur

Django basiert auf einer Abwandlung der klassischen #htl3r.full[mvc]-Architektur, die als #htl3r.full[mvt] bezeichnet wird @django-docs. #htl3r.long[diagnet] nutzt dieses Paradigma für eine strikte Trennung von Datenmodellierung, Geschäftslogik und Präsentationsebene.

Das *Model* definiert die Datenstrukturen und kommuniziert mit der Datenbank. Die *View* nimmt #htl3r.full[http]-Requests entgegen, orchestriert die #htl3r.long[backend]-Logik und bereitet die Daten auf. Das *Template* rendert die von der View übergebenen Variablen in valides #htl3r.short[html].

=== "Fat Models": Integration der Netzwerk-Engines

#htl3r.long[diagnet] folgt darüber hinaus auch dem "Fat Models"-Prinzip: Die Geschäftslogik wird nicht in den Views implementiert, sondern direkt in den Datenmodellen gekapselt. Das `Device`-Modell dient dabei als direkte Schnittstelle zur Netzwerk-Engine #htl3r.long[pyats]. Die netzwerktechnischen Grundlagen, Parsing-Mechanismen und statischen #htl3r.longpl[testbed] von #htl3r.long[pyats] werden in @pyats_chapter erläutert.

#pagebreak()

Das `Device`-Modell erzeugt aus seinen eigenen Tabellenspalten (IP, Username, Password) dynamisch die benötigten #htl3r.long[pyats]-#htl3r.longpl[testbed] und instanziiert die Verbindungen direkt im Speicher des #htl3r.longpl[backend]. Bereits offene Verbindungen werden über ein globales Cache-Dictionary (`device_connections`) für nachfolgende Tests wiederverwendet. Da `is_connected()` nur den lokalen Verbindungsstatus prüft, wird die Session zusätzlich mit einem #box(`show clock`)-Befehl aktiv verifiziert. Schlägt dieser fehl, wird der Cache-Eintrag verworfen und eine neue Verbindung aufgebaut:

#htl3r.code(
  caption: [Dynamische Instanziierung von pyATS-Geräteobjekten aus der Datenbank],
  description: `devices/models.py`,
)[
  ```python
    def get_genie_device_object(self):
      device = device_connections.get(self.pk)
      if device:
          try:
              if device.is_connected():
                  device.execute("show clock", timeout=5)
                  return device
          except Exception:
              pass
          device_connections.pop(self.pk, None)

      conn_info = self.get_genie_device_dict()
      testbed = load({"devices": conn_info})
      device = testbed.devices[list(conn_info)[0]]
      device.connect(timeout=15)
      device_connections[self.pk] = device
      return device
  ```
]

Dieses Design entkoppelt das Web-Routing vollständig von der Netzwerkkommunikation. Die Views rufen zur Testausführung lediglich `testcase.run()` auf. Das Modell lädt anschließend dynamisch über `importlib` den geforderten Test-Code, kompiliert die Parameter und initiiert die #htl3r.short[ssh]-Verbindung.
