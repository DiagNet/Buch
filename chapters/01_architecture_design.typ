#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Danijel Stamenkovic")
= Design und Aufbau der Infrastruktur

Für die Umsetzung von DiagNet war eine Testumgebung notwendig, in der sowohl reale Netzwerkeigenschaften als auch komplexe Topologien abgebildet werden können. Eine rein virtuelle Umgebung hätte zwar viel Flexibilität geboten, jedoch lassen sich bestimmte Funktionen wie Port-Security, VLAN-Zuweisungen oder das Verhalten physischer Switch-Ports nur eingeschränkt realistisch testen.

Aus diesem Grund wurde ein hybrider Ansatz gewählt, der aus einer Kombination von echter Hardware und einer virtuellen Umgebung auf Basis von GNS3 besteht. Ziel war es, eine möglichst praxisnahe Infrastruktur aufzubauen, die gleichzeitig flexibel erweiterbar bleibt.

#figure(
  image("../assets/Topologie - DiagNet.jpg", width: 95%),
  caption: [Detaillierte Topologie: Links die virtuelle GNS3-Instanz, rechts die physische Hardware, verbunden über den 802.1Q Trunk.],
) <fig-hybrid-arch>



== Entscheidung für ein hybrides Design

Der hybride Aufbau ermöglicht es, sicherheitskritische und ressourcenintensive Komponenten auf echter Hardware zu betreiben, während Router, WAN-Strecken und zusätzliche Standorte virtuell realisiert werden.

Dadurch können reale Tests durchgeführt werden, ohne auf die Vorteile einer Simulation verzichten zu müssen. Gerade für Testszenarien mit wechselnden Anforderungen ist diese Flexibilität ein großer Vorteil.




== Physische Infrastruktur

Die physische Umgebung besteht aus einem Multilayer-Switch, mehreren Access-Switches sowie verschiedenen Security-Komponenten.

Der Multilayer-Switch übernimmt die Rolle des zentralen Verteilers. Auf diesem Gerät werden VLANs konfiguriert, Inter-VLAN-Routing durchgeführt und die Verbindung zur virtuellen Umgebung hergestellt.

An den Access-Switches sind Endgeräte wie Test-PCs oder Laptops angeschlossen. Diese Switches werden verwendet, um Funktionen wie Port-Security, VLAN-Zuweisung und Zugriffsbeschränkungen praxisnah zu testen.

Zusätzlich kommt eine Cisco Identity Services Engine (ISE) zum Einsatz, die für die Authentifizierung von Clients zuständig ist. Da dieser Dienst hohe Anforderungen an CPU und Arbeitsspeicher stellt, wird er auf dedizierter Hardware betrieben, um einen stabilen Betrieb zu gewährleisten.



== Virtuelle Umgebung (GNS3)

In der virtuellen Umgebung werden hauptsächlich Router und WAN-Strecken simuliert. Dazu zählen Core-Router, Standort-Router sowie eine Internet-Anbindung über eine NAT-Cloud.

Diese Struktur ermöglicht es, Routing-Protokolle, Redundanzmechanismen und Ausfallszenarien zu testen, ohne Änderungen an der physischen Verkabelung vornehmen zu müssen.



== Verbindung zwischen physischer und virtueller Umgebung

Die Verbindung zwischen Hardware und GNS3 erfolgt über einen Trunk-Port des Multilayer-Switches, der mit einer zweiten Netzwerkkarte des GNS3-Servers verbunden ist.

Damit VLAN-Tags korrekt in GNS3 ankommen, wurde auf dem Server das VLAN-Offloading deaktiviert. Zusätzlich läuft die Netzwerkkarte im Promiscuous Mode, sodass getaggte Ethernet-Frames unverändert an die virtuellen Geräte weitergegeben werden.



== Routing-Konzept

Für die Kommunikation zwischen allen Netzwerkteilen wird ein dynamisches Routing-Protokoll eingesetzt. Statische Routen wären bei der Größe der Infrastruktur nur schwer wartbar.

Es wird OSPFv2 (Open Shortest Path First) verwendet.

Das Netzwerk ist in mehrere Areas unterteilt:

- Area 0: Backbone-Area mit Multilayer-Switch und virtuellen Core-Routern
- Area 1: Enthält die simulierten Außenstellen

Fällt eine Verbindung aus, berechnet OSPF automatisch eine alternative Route.



== Management-Netzwerk

Zusätzlich zum produktiven Netzwerk existiert ein separates Management-Netzwerk.

Jedes physische Gerät verfügt über einen dedizierten Management-Port. Diese Ports befinden sich in VLAN 10 und sind vollständig vom produktiven Datenverkehr getrennt.

Auch bei fehlerhaften Konfigurationen im produktiven Netzwerk bleibt der Zugriff auf die Geräte über das Management-Netz bestehen.



== IP-Adressierung

Das verwendete IP-Adressschema lautet:

`10.Site.VLAN.Host`

Zusätzlich wird anhand des Hostbereichs unterschieden, ob es sich um physische oder virtuelle Geräte handelt:

- 1–100: Physische Geräte
- 101–200: Virtuelle Geräte

Beispiel:

- `10.1.20.5` – Physischer Server
- `10.1.20.150` – Virtueller Router

Dieses Schema erleichtert die Übersicht und wird auch für Automatisierungsskripte verwendet.



== Native-VLAN-Strategie

Standardmäßig wird VLAN 1 als Native VLAN verwendet. Im hybriden Betrieb führte dies zu Problemen bei der Übergabe von ungetaggten Frames.

Aus diesem Grund wurde das Native VLAN global auf VLAN 999 geändert. Dadurch ist jedes produktive Paket gezwungen, ein VLAN-Tag zu tragen. Ungetaggte Frames werden VLAN 999 zugeordnet und beeinflussen das produktive Netzwerk nicht.

Diese Maßnahme erhöht die Stabilität der Verbindung zwischen physischer Infrastruktur und GNS3 deutlich.



== Dokumentation und Strukturierung

Alle relevanten Informationen zur Infrastruktur werden dokumentiert. Dazu zählen Topologiepläne, IP-Adressbereiche, VLAN-Übersichten sowie Gerätebezeichnungen.

Die Dokumentation wird im selben GitHub-Repository wie das Diplomarbeitsbuch verwaltet. Änderungen an der Infrastruktur können dadurch versioniert nachvollzogen werden.

Diese Vorgehensweise ermöglicht es auch anderen Personen, die Umgebung später nachzubauen oder weiterzuentwickeln.



== Namenskonzept für Netzwerkgeräte

Für alle Netzwerkgeräte wurde ein einheitliches Namensschema definiert.

Das Schema setzt sich aus Gerätekategorie, Standort und laufender Nummer zusammen, zum Beispiel:

- CORE-R1
- DIST-SW1
- ACC-SW1
- SITE1-R1

Durch dieses Namenskonzept ist bereits anhand des Gerätenamens erkennbar, welche Funktion ein Gerät im Netzwerk übernimmt.



== Trennung zwischen Testumgebung und Infrastruktur

Ein wesentliches Designprinzip von DiagNet ist die klare Trennung zwischen der zugrunde liegenden Infrastruktur und den darauf ausgeführten Testfällen.

Die Infrastruktur stellt ausschließlich die Netzwerkumgebung bereit (Router, Switches, Verbindungen, IP-Strukturen und Routing). Die eigentlichen Testcases sind davon logisch getrennt und greifen nur über definierte Schnittstellen auf die Geräte zu.

Dadurch sind die Testfälle unabhängig vom konkreten Aufbau der Topologie. Ein Testcase beschreibt, *was* überprüft werden soll (z. B. Erreichbarkeit eines Geräts oder Vorhandensein einer Route), jedoch nicht, *wie* die Infrastruktur intern umgesetzt ist.

Diese Entkopplung hat mehrere Vorteile:

- Testfälle können unverändert weiterverwendet werden, auch wenn sich die Topologie ändert
- Neue Standorte oder Geräte können hinzugefügt werden, ohne bestehende Tests anpassen zu müssen
- Fehler lassen sich besser eingrenzen, da klar zwischen Infrastrukturproblemen und Testlogik unterschieden werden kann

Somit fungiert die Infrastruktur als hilfreiche Basis, während die Testcases flexibel und unabhängig davon weiterentwickelt werden können.
