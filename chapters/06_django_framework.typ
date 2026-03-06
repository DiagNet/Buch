#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Karun Sandhu")
= Backend & Applikationsarchitektur <backend_architektur>

Die serverseitige Logik und die Datenhaltung bilden das Fundament von #htl3r.long[diagnet]. In diesem Kapitel wird die Architektur des #htl3r.longpl[backend] detailliert beleuchtet. Der Fokus liegt dabei auf der Strukturierung der Applikation, der Abbildung der Netzwerktopologie in einer relationalen Datenbank sowie der sicheren Verarbeitung sensibler Gerätedaten und Testparameter.

== Das Django Framework <django_framework>

Für die Entwicklung der zentralen Verwaltungsplattform von #htl3r.long[diagnet] fiel die Wahl auf das in Python geschriebene Web-#htl3r.long[framework] Django. Django folgt dem Prinzip "Batteries included" @django-docs, was bedeutet, dass wesentliche Kernkomponenten wie Authentifizierung, Session-Management und Schutzmechanismen gegen Web-Vulnerabilitäten bereits standardmäßig in das #htl3r.long[framework] integriert sind. Wie diese integrierten Mechanismen konkret genutzt werden, um die Plattform sowie sensible Gerätedaten zu schützen, wird in @data_security detailliert behandelt.

Da #htl3r.long[diagnet] stark datengetrieben ist und komplexe Relationen zwischen Netzwerkgeräten, Testfällen und historischen Testergebnissen abbilden muss, bietet Django mit seinem integrierten #htl3r.full[orm] die optimale Grundlage. Dies erlaubte es dem Projektteam, den Fokus auf die netzwerkspezifische Geschäftslogik zu legen, anstatt grundlegende #htl3r.short[sql]-Zugriffe von Hand implementieren zu müssen. Das resultierende Datenbankschema und die konkreten Modellentscheidungen sind in @data_security dokumentiert.

=== Alternativen und Entscheidungsfindung

Die Wahl des serverseitigen #htl3r.long[framework]s wurde maßgeblich durch das eingesetzte Netzwerkautomatisierungs-Tool #htl3r.long[pyats] @pyats-docs beeinflusst. Da diese nativ auf Python basieren, war ein Python-#htl3r.long[backend] zwingend erforderlich, um aufwendige Schnittstellen zu anderen Programmiersprachen zu vermeiden. Um zwischen den populärsten Python-#htl3r.long[framework]s Django, Flask und FastAPI, eine fundierte Entscheidung zu treffen, wurde eine Nutzwertanalyse durchgeführt.

Folgende vier Kriterien wurden für die Bewertung definiert:
- *Funktionsumfang:* Verfügbarkeit von essenziellen "Out-of-the-Box" Features, wie #htl3r.short[orm] und Authentifizierung.
- *Tool-Integration:* Nahtlose Einbindung der nativen Python-Netzwerk-Bibliotheken.
- *Rendering:* Eignung für klassisches, serverseitiges #htl3r.short[html]-Rendering.
- *#htl3r.short[api]-Fokus:* Ausrichtung auf reine Schnittstellen-Entwicklung (für #htl3r.long[diagnet] aufgrund des Setup-Aufwands weniger relevant).

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

==== Punktevergabe und Auswertung

Im zweiten Schritt wurden die #htl3r.long[framework]s in den einzelnen Kategorien mit Punkten von 1 (sehr schlecht/gering) bis 5 (sehr gut/hoch) bewertet. Das Kriterium "#htl3r.short[api]-Fokus" floss mit der Gewichtung 0 nicht in die finale Punktzahl ein, wurde der Vollständigkeit halber jedoch evaluiert.

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
  caption: [Nutzwertanalyse und finale Auswertung der #htl3r.long[framework]s],
) <nutzwertanalyse>

==== Beste Option für unser Projekt: Django

Im Rahmen der Entscheidungsanalyse kristallisierte sich Django (30 Punkte) als klarer Sieger heraus. Zwar bieten alle drei #htl3r.long[framework]s eine exzellente und nahtlose Integration der benötigten Python-Netzwerk-Tools (jeweils 5 Punkte), jedoch zeigten sich massive Unterschiede beim Funktionsumfang.

Flask und FastAPI sind hervorragende Micro-#htl3r.long[framework]s, erfordern für den Aufbau einer klassischen #htl3r.short[mvt]-Applikation mit Datenbank und Authentifizierung jedoch das manuelle Zusammenstellen von Drittanbieter-Bibliotheken. Django liefert als einziges #htl3r.long[framework] wesentliche Kernfunktionen von Haus aus mit. Diese massive Zeitersparnis bei den Web-Grundlagen ermöglichte es dem Team, den Entwicklungsfokus vollständig auf die komplexe Geschäftslogik und die Automatisierung der Netzwerktests zu legen.

=== Applikationsstruktur und Modularität

Um die Komplexität des Gesamtsystems zu kapseln und die Wartbarkeit zu erhöhen, wurde das #htl3r.long[backend] von #htl3r.long[diagnet] in mehrere entkoppelte Module in sogenannte Django-Apps unterteilt. Diese strikte Trennung fördert die Wiederverwendbarkeit des Codes und spiegelt die in der Planungsphase definierten Projektziele wider.

Wie in der zentralen Konfigurationsdatei der Applikation definiert, besteht das System neben den Django-Standardkomponenten aus vier essenziellen Kern-Apps, die jeweils einen abgegrenzten Verantwortungsbereich besitzen:

- *`accounts`*: Verwaltet die Benutzerverwaltung und Zugriffskontrolle der Plattform. Dies umfasst die Definition von Benutzerrollen, die Vergabe von Berechtigungen sowie die Authentifizierung der Administratoren.
- *`dashboard`*: Zuständig für die grafische Übersicht und die zentrale Einstiegsseite der Webanwendung. Hier laufen Metriken und Statusinformationen zusammen.
- *`devices`*: Beinhaltet die gesamte Geschäftslogik zur Verwaltung der Netzwerkgeräte. Dies umfasst die Validierung der Verbindungsparameter, die Speicherung der Zugangsdaten und die Bereitstellung von Schnittstellen für die Netzwerk-Engines.
- *`networktests`*: Das Herzstück der Testausführung. Diese App verwaltet die Struktur der Testfälle, deren dynamische Parameter und protokolliert die Historie der Testergebnisse. Zudem beinhaltet sie die logische Gruppierung von Testfällen, sodass Netzwerkadministratoren ganze Test-Batches zusammenfassen und gesammelt ausführen können.

Durch die vollständige Abstraktion mittels #htl3r.short[orm] kann diese relationale Datenbank im produktiven Einsatz bei Bedarf durch leistungsstärkere Systeme wie PostgreSQL ausgetauscht werden. Dies erfordert eine Anpassung der Datenbankeinstellungen sowie die Installation des entsprechenden Datenbanktreibers, jedoch können die Datenmodelle und die Programmlogik vollkommen unberührt bleiben.

=== Model-View-Template (MVT) Architektur

Django basiert auf einer leichten Abwandlung der klassischen #htl3r.full[mvc]-Architektur, die als Model-View-Template (#htl3r.short[mvt]) bezeichnet wird @django-docs. #htl3r.long[diagnet] nutzt dieses Paradigma für eine strikte Trennung von Datenmodellierung, Geschäftslogik und Präsentationsebene.

In der #htl3r.short[mvt]-Architektur übernimmt das *Model* die Definition der Datenstrukturen und die Kommunikation mit der Datenbank. Die *View* fungiert als Controller: Sie nimmt #htl3r.short[http]-Requests entgegen, orchestriert #htl3r.long[backend]-Logiken (wie das Auslösen eines Pings zu einem Switch) und bereitet die Daten auf. Das *Template* ist ausschließlich für die Darstellung im Browser zuständig und rendert die von der View übergebenen Variablen in valides #htl3r.short[html].

=== "Fat Models": Integration der Netzwerk-Engines

#htl3r.long[diagnet] folgt dem "Fat Models"-Prinzip: Die Geschäftslogik wird nicht in den Views implementiert, sondern direkt in den Datenmodellen gekapselt. Das `Device`-Modell dient dabei als direkte Schnittstelle zur externen Netzwerk-Engine #htl3r.long[pyats]. Die netzwerktechnischen Grundlagen, Parsing-Mechanismen und statischen #htl3r.longpl[testbed] von #htl3r.long[pyats] werden in @pyats_chapter erläutert.

Anstatt Verbindungslogiken extern zu verwalten, erzeugt das `Device`-Modell aus seinen eigenen Tabellenspalten (IP, Username, Password) dynamisch die benötigten #htl3r.long[pyats]-#htl3r.longpl[testbed] und instanziiert die Verbindungen direkt im Speicher des #htl3r.longpl[backend]. Um Ressourcen zu schonen, wurde zudem ein globales Caching implementiert (`device_connections`), das bereits offene Verbindungen für nachfolgende Tests wiederverwendet:

#htl3r.code(
  caption: [Dynamische Instanziierung von #htl3r.long[pyats]-Geräteobjekten aus der Datenbank],
  description: `devices/models.py`,
)[
  ```python
  def get_genie_device_object(self):
      if (self.name in device_connections and
          device_connections[self.name].is_connected()):
          return device_connections[self.name]

      conn_info = self.get_genie_device_dict()
      testbed = load({"devices": conn_info})
      device = testbed.devices[list(conn_info)[0]]

      try:
          device.connect()
          device_connections[self.name] = device
          return device
      except Exception:
          return None
  ```
]

Dieses Design entkoppelt das eigentliche Web-Routing vollständig von der Netzwerkkommunikation. Die Views rufen zur Testausführung lediglich `testcase.run()` auf. Das Modell lädt anschließend dynamisch über das `importlib`-Modul den geforderten Test-Code, kompiliert die Parameter und initiiert die #htl3r.short[ssh]-Verbindung.
