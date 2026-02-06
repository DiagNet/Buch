// Has to be imported for function use
#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Benedikt Theuretzbachner")
= PyATS
== Einführung
PyATS ist ein Test- und Automatisierungs-Framework, welches Python-basiert ist und von Cisco entwickelt wird. Es spezialisiert sich vor allem auf das Testen von Netzwerkgeräten aus dem Cisco Ökosystem, jedoch unterstützt es auch andere Plattformen.

== Automatisiertes Testen von Netzwerken
Automatisierung im Netzwerkbereich ist ein Thema, welches zunehmend an Relevanz gewinnt. Die Effizienz von Netzwerkperationen wird durch eien automatische Ausführung erheblich gesteigert. Außerdem kann bei diesem Konzept das menschliche Versagen nur noch bei dem Aufsetzen der Automatisierung selbst auftreten.

Das Testen von Infrastrukturen stellt einen besonders geeigneten Anwendungsbereich dar. Wird dieses manuell ausgeführt, müssen bei jeder Änderung an Systemen bestimmte Befehle händisch ausgeführt werden. Mit einem automatisierten Ansatz kann dieser Aufwand minimiert werden, da es möglich ist, die gesamte Infrastruktur mit einem Befehl oder Knopfdruck zu testen.

== Eignung für das Projekt
Das Ziel von DiagNet ist es, ein Programm zu erschaffen, welches das Testen von Netzwerken angenehmer und effizienter gestaltet. PyATS eignet sich für diesen Zweck, da es praktische Funktioen für das Handhaben von Verbindungen zu Geräten bietet.

Zusätzlich ermöglicht es, Daten auf Netzwerkgeräten zu sammeln und sie in ein für die weitere Verarbeitung in Python geeignetes Format umzuwandeln. Diese Funktionalität bietet eine Grundlage für die automatisierte Analyse und Auswertung innerhalb von DiagNet.

== Grundlagen von PyATS
=== Architektur
PyATS besteht aus einer modularen Architektur. Eine seiner wichtigsten Komponenten ist Genie. Dabei handelt es sich um eine Library innerhalb von PyATS, welche zahlreiche Parser zur Verfügung stellt. Ein Parser ist dafür verantwortlich, den Geräteoutput in ein verwendbares Format umzuwandeln.

Bei Genie kann es sich dabei konkret um show-Befehle handeln. Diese werden auf Geräten wie Cisco Routern eingesetzt, um Informationen über den aktuellen Zustand des Systems anzuzeigen. Da die Befehle lediglich Text zurückgeben, wandeln Genie Parser diesen in Python dictionary-Strukturen um. Darauf kann im Programmcode ohne Weiteren Aufwand direkt zugegriffen werden.

Weitere Komponenten von PyATS sind AEtest, welches die Basis für die Strukturierung der Testfälle und Automatisierung der Testabläufe darstellt, sowie Unicon. Letzteres kümmert sich um die Geräteverbindungen und bietet eine einheitliche Schnittstelle um auf Protokolle sie SSH oder Telnet zuzugreifen.

== Testbeds <testbeds>
Ein Testbed in PyATS ist eine Datei, in der zur Verbindung benötigte Daten von Geräten deklariert werden.
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

Testbeds werden in dem Format YAML gespeichert und können folgendermaßen aussehen:
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
Dieses Beispiel enthält lediglich einen Router, es können aber auch mehrere Geräteverbindungen in einem Testbed definiert werden.

== PyATS Testskript
Wie bereits erwähnt ist PyATS in der Programmiersprache Python geschrieben. Es beitet eine umfangreiche Programmierschnittstelle, auf die man in eigenem Programmcode zugreifen kann. Dazu muss das richtige Paket installiert werden, was in Python auf mehrere Arten erledigt werden kann. Da das Projekt DiagNet auf die Paketverwaltungssoftware *uv* setzt, wurde folgender Befehl verwendet:
```bash
uv add pyats[full]
```
*Full* gibt an, dass alle Komponenten des Frameworks installiert werden sollen.

Mit diesem Paket und dem Testbed von @testbeds kann ein Python-Skript geschrieben werden, welches die Funktionalität von PyATS demonstriert:
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
Der Ablauf des Skripts kann in folgende Teile gegliedert werden:
+ Am Anfang werden die benötigten Genie Komponenten und pprint importiert. Pprint ist dafür zuständig, die Ausgaben der Funktionen in einem übersichtlichen Format darzustellen.
+ Danach wird das Testbed geladen und in eine Variable gespeichert. Von dieser wird dann ein bestimmtes Gerät, in diesem Fall der Router R1, ausgewählt und in einer eigenen Variable "device" gespeichert.
+ Auf 'device' kann jetzt mit diversen Genie Methoden zugegriffen werden. Eine davon ist *parse*. Sie erwartet als Parameter einen show-Befehl, von dem die Ausgabe geparsed, also in ein verwendbares Format umgewandelt wird. Bei dem obigen Beispiel des Befehls "show version" sieht die gekürzte Ausgabe folgendermaßen aus:
  ```
  {'version': {'chassis': 'IOSv',
               ...
               'version': '15.9(3)M6',
               'version_short': '15.9'}}
  ```
  Hier ist klar ersichtlich, dass die Ausgabe in die Form eines Python-Dictionaries gebracht wurde. Falls kein passender Parser vorhanden ist, wirft das Programm eine *genie.libs.parser.utils.common.ParserNotFound* Exception.
+ Anschließend wird von dem "device" Objekt ein Interface Objekt erstellt. Mit diesem können durch die "learn" Methode sämtliche Informationen über Interfaces auf dem Router gesammelt und als Python-Dictionary zurückgeben werden. Die Umfangreiche Ausgabe wird durch `interfaces.info["GigabitEthernet0/0"]["enabled"]` auf den Status eines bestimmten Interfaces, hier GigabitEthernet0/0, reduziert.
