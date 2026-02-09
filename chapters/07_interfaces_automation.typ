#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Benedikt Theuretzbachner")
== Schnittstellen & Parsing mit #htl3r.long[pyats]
#htl3r.long[pyats] ist ein Test- und Automatisierungs-#htl3r.long[framework], welches Python-basiert ist und von Cisco entwickelt wird. Es spezialisiert sich vor allem auf das Testen von Netzwerkgeräten aus dem Cisco Ökosystem, jedoch unterstützt es auch andere Plattformen.

=== Automatisiertes Testen von Netzwerken
Automatisierung im Netzwerkbereich ist ein Thema, welches zunehmend an Relevanz gewinnt. Die Effizienz von Netzwerkoperationen wird durch eine automatische Ausführung erheblich gesteigert. Außerdem kann bei diesem Konzept das menschliche Versagen nur noch bei dem Aufsetzen der Automatisierung selbst auftreten.

Das Testen von Infrastrukturen stellt einen besonders geeigneten Anwendungsbereich dar. Wird dieses manuell ausgeführt, müssen bei jeder Änderung an Systemen bestimmte Befehle händisch ausgeführt werden. Mit einem automatisierten Ansatz kann dieser Aufwand minimiert werden, da es möglich ist, die gesamte Infrastruktur mit einem Befehl oder Knopfdruck zu testen.

=== Eignung für das Projekt
Das Ziel von DiagNet ist es, ein Programm zu erschaffen, welches das Testen von Netzwerken angenehmer und effizienter gestaltet. #htl3r.long[pyats] eignet sich für diesen Zweck, da es praktische Funktionen für das Handhaben von Verbindungen zu Geräten bietet.

Zusätzlich ermöglicht es, Daten auf Netzwerkgeräten zu sammeln und sie in ein für die weitere Verarbeitung in Python geeignetes Format umzuwandeln. Diese Funktionalität bietet eine Grundlage für die automatisierte Analyse und Auswertung innerhalb von DiagNet.

=== Grundlagen
#htl3r.long[pyats] besteht aus einer modularen Architektur. Eine seiner wichtigsten Komponenten ist #htl3r.long[genie]. Dabei handelt es sich um eine Library innerhalb von #htl3r.long[pyats], welche zahlreiche #htl3r.long[parser] zur Verfügung stellt. Ein #htl3r.long[parser] ist dafür verantwortlich, den Geräteoutput in ein verwendbares Format umzuwandeln.

Bei #htl3r.long[genie] kann es sich dabei konkret um show-Befehle handeln. Diese werden auf Geräten wie Cisco Routern eingesetzt, um Informationen über den aktuellen Zustand des Systems anzuzeigen. Da die Befehle lediglich Text zurückgeben, wandeln #htl3r.long[genie] #htl3r.long[parser] diesen in Python dictionary-Strukturen um. Darauf kann im Programmcode ohne weiteren Aufwand direkt zugegriffen werden.

Weitere Komponenten von #htl3r.long[pyats] sind #htl3r.long[aetest], welches die Basis für die Strukturierung der Testfälle und Automatisierung der Testabläufe darstellt, sowie #htl3r.long[unicon]. Letzteres kümmert sich um die Geräteverbindungen und bietet eine einheitliche Schnittstelle um auf Protokolle sie #htl3r.long[ssh] oder #htl3r.long[telnet] zuzugreifen.

=== Testbeds <testbeds>
Ein #htl3r.long[testbed] in #htl3r.long[pyats] ist eine Datei, in der zur Verbindung benötigte Daten von Geräten deklariert werden.
Zu diesen Daten gehören:
- Gerätename
- Betriebssystem/Plattform
- Zugangsdaten
- Verbindungsart

Zu den relevantesten unterstützten Betriebssystemen/Plattformen gehören:
- Cisco IOS - Klassisches Betriebssystem für Router und Switches
- Cisco IOXE - Modularer, Linux-basierter nachfolger von IOS
- Cisco IOSXR - Optimiert für Einsatz bei Service Providern
- Cisco NXOS - Betriebssystem für Datacenter-Switches
- Cisco ASA - Betriebssystem für Firewalls

Testbeds werden in dem Format #htl3r.short[yaml] gespeichert und können folgendermaßen aussehen:

#htl3r.code(
  caption: [Ein Beispiel einer Testbed-Datei],
  description: `testbed.yaml`,
)[
  ```yaml
  devices:
    Router-1:             # Hostname des Gerätes
      type: router
      os: iosxe           # Betriebssystem
      credentials:        # Zugangsdaten
          default:
              username: dnadmin
              password: Cisco123!
      connections:        # Daten für den Verbindungsaufbau
        cli:
          protocol: ssh
          ip: 172.25.192.90
  ```
]

Dieses Beispiel enthält lediglich einen Router, es können aber auch mehrere Geräteverbindungen in einem Testbed definiert werden.

=== PyATS Testskript
Wie bereits erwähnt ist #htl3r.long[pyats] in der Programmiersprache Python geschrieben. Es bietet eine umfangreiche Programmierschnittstelle, auf die man in eigenem Programmcode zugreifen kann. Dazu muss das richtige Paket installiert werden, was in Python auf mehrere Arten erledigt werden kann. Da das Projekt DiagNet auf die Paketverwaltungssoftware uv setzt, wurde folgender Befehl verwendet:
```bash
uv add pyats[full]
```
*Full* gibt an, dass alle Komponenten des Frameworks installiert werden sollen.

Mit diesem Paket und dem Testbed von @testbeds kann ein Python-Skript geschrieben werden, welches die Funktionalität von #htl3r.long[pyats] demonstriert:
#pagebreak()

#htl3r.code(
  caption: [Ein #htl3r.long[pyats] Beispielskript],
  description: `script.py`,
)[
  ```python
  from genie.testbed import load
  from genie.libs.ops.interface.ios.interface import Interface

  from pprint import pprint


  # Datei mit den Verbindungsinformationen von Routern laden:
  tb = load("testbed1.yml")

  # Mit einem bestimmten Router verbinden:
  device = tb.devices["R1"]
  device.connect(log_stdout=False)

  # Informationen über die Plattform und Version des Betriebssystems ausgeben:
  version = device.parse("show version")
  pprint(version)


  # Den Status von Gig0/0 ausgeben:
  interfaces = Interface(device)
  interfaces.learn()
  pprint(interfaces.info["GigabitEthernet0/0"]["enabled"])

  # Informationen über den ospf Prozess ausgeben:
  ospf = device.learn("ospf")
  pprint(ospf.info)
  ```
]
Der Ablauf des Skripts kann in folgende Teile gegliedert werden:
+ Am Anfang werden die benötigten #htl3r.long[genie] Komponenten und pprint importiert. Pprint ist dafür zuständig, die Ausgaben der Funktionen in einem übersichtlichen Format darzustellen.

+ Danach wird das Testbed geladen und in eine Variable gespeichert. Von dieser wird dann ein bestimmtes Gerät, in diesem Fall der Router R1, ausgewählt und in einer eigenen Variable "device" gespeichert.

+ Auf 'device' kann jetzt mit diversen #htl3r.long[genie] Methoden zugegriffen werden. Eine davon ist parse. Sie erwartet als Parameter einen show-Befehl, von dem die Ausgabe geparsed, also in ein verwendbares Format umgewandelt wird. Bei dem obigen Beispiel des Befehls "show version" sieht die gekürzte Ausgabe folgendermaßen aus:
  ```
  {'version': {'chassis': 'IOSv',
               ...
               'version': '15.9(3)M6',
               'version_short': '15.9'}}
  ```
+ Hier ist klar ersichtlich, dass die Ausgabe in die Form eines Python-Dictionaries gebracht wurde. Falls kein passender Parser vorhanden ist, wirft das Programm eine genie.libs.parser.utils.common.ParserNotFound #htl3r.long[exception].

+ Anschließend wird von dem "device" Objekt ein #htl3r.long[interface] Objekt erstellt. Mit diesem können durch die "learn" Methode sämtliche Informationen über Interfaces auf dem Router gesammelt und als Python-Dictionary zurückgegeben werden. Die Umfangreiche Ausgabe wird durch interfaces.info["GigabitEthernet0/0"]["enabled"] auf den Status eines bestimmten Interfaces, hier GigabitEthernet0/0, reduziert. Die Ausgabe beschränkt sich daher auf True, bei einem aktiven Interface, und False, bei einem inaktiven Interface.

+ Zuletzt wird im obigen Script die "learn" Methode mit dem Parameter "#htl3r.long[ospf]" ausgeführt. Diese gibt folglich alle Informationen über das dynamische #htl3r.long[routingprotokoll] #htl3r.long[ospf] zurück, welche #htl3r.long[pyats] von einem Router extrahieren kann.
Einige davon, welche häufig benötigt werden, sind:
- #htl3r.long[router_id]
- #htl3r.long[ospf_area]s
- Jegliche Timer
- OSPF-Prozess-ID
- OSPF-Version (v2/v3)
- #htl3r.long[neighbor]s

- Routen in der OSPF-Routing-Tabelle
Folgendes stellt den Teil der Ausgabe des Befehls dar, welcher Informationen über die OSPF-Areas liefert:
```
'areas': {'0.0.0.0': {'area_id': '0.0.0.0',
                      'area_type': 'normal',
                      'mpls': {'te': {'enable': False}},
                      'statistics': {'area_scope_lsa_cksum_sum': '0x000000',
                                    'area_scope_lsa_count': 0,
                                    'spf_runs_count': 0}}},
```

=== Integration in die DiagNet-Applikation
#htl3r.long[pyats] wird im #htl3r.long[backend] von DiagNet eingesetzt, da dieser Teil des Programmcodes unter anderem dafür verantwortlich ist, mit den zu testenden Netzwerkgeräten zu interagieren und von ihnen diverse Informationen zu extrahieren.
==== Technische Anbindung
Um die Funktionalität von #htl3r.long[pyats] in der DiagNet Applikation nutzen zu können, werden mehrere Datenstrukturen benötigt. Eine von ihnen ist eine Liste, die mit Geräteobjekten bzw. Geräteverbindungen befüllt wird. Dieses Speichern von Verbindungen hat den Vorteil, dass bei dem Ausführen von Testfällen nicht immer neue Objekte erstellt werden müssen. Folglich wird die Anzahl der offenen Verbindungen kleiner, was sowohl den Prozess der DiagNet Anwendung, als auch die Netzwerkgeräte entlastet.
Von dieser Liste bekommt das Backend ein #htl3r.long[genie]-Device-Objekt. In den einzelnen Testfällen wird dann spezifiziert, welche #htl3r.long[pyats]-Methoden mit dem Objekt ausgeführt werden müssen, um die für die Auswertung erforderlichen Informationen zu erhalten.

=== Zusammenfassung
Bei #htl3r.long[pyats] handelt es sich um ein Framework zur Automatisierung von Netzwerktests. Durch die Kombination aus strukturierten Testabläufen und der Aufbereitung von Geräteinformationen eignet sich #htl3r.long[pyats] besonders für den Einsatz in automatisierten Testumgebungen.
Trotz der umfangreichen Funktionalität ist die Nutzung von #htl3r.long[pyats] an gewisse Einschränkungen gebunden, wie etwa die Verfügbarkeit geeigneter Parser oder den Fokus auf bestimmte Plattformen. Diese Grenzen können jedoch durch eine gezielte Auswahl unterstützter Tests sowie durch Erweiterungen in zukünftigen Versionen teilweise kompensiert werden.
