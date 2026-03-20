#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Danijel Stamenkovic")

= Design und Aufbau der Infrastruktur <architektur>

Damit #htl3r.long[diagnet] unter realistischen Bedingungen entwickelt und getestet werden konnte, wurden zwei voneinander unabhängige Umgebungen aufgebaut. Der erste Bereich umfasst das physische Labor mit echter Cisco-Hardware. Der zweite Bereich ist eine vollständig separate Simulationsumgebung auf Basis von #htl3r.full[gns3]. Beide Umgebungen sind nicht miteinander verbunden und wurden jeweils eigenständig betrieben.

Diese Trennung wurde bewusst gewählt, da eine reine Simulation für viele Testfälle nicht die erforderliche Aussagekraft besitzt. Sicherheitsfunktionen wie Port-Security verhalten sich auf den physischen Chips eines Switches oft anders als in einer Software-Simulation. Dadurch konnten dieselben Testfälle einmal in der Simulation und einmal an realer Hardware ausgeführt und die Ergebnisse verglichen werden.

Im Entwicklungsalltag erfüllten die beiden Umgebungen dennoch unterschiedliche Rollen. Neue Testfälle und Topologieänderungen wurden zunächst in GNS3 erprobt, da dort Anpassungen schnell und ohne Auswirkungen auf laufende Systeme vorgenommen werden konnten. Sobald ein Testfall stabil lief, wurde er anschließend am physischen Labor validiert. Dieser zweistufige Ablauf half dabei, Fehler frühzeitig zu erkennen, bevor echte Hardware in die Tests einbezogen wurde.

#pagebreak()

== Physischer Standort (Labor)

Im physischen Labor befindet sich die Hardware von Cisco, welche von der Firma CANCOM Austria AG bereitgestellt wurde. Die Abbildung @fig-physische-topologie zeigt das Zusammenspiel der einzelnen Komponenten an diesem Standort.

#figure(
  image("../assets/topo_echtgeraete.png", width: 96%),
  caption: [
    Physische Topologie: Das Cisco-Labor mit den Zone-Based Firewalls (ZBFW-1, ZBFW-2), dem Distribution-Switch (DSW), den Access-Switches (ASW-1, ASW-2) und der Cisco ISE.
  ],
) <fig-physische-topologie>

Der Zugang zum Labor erfolgt über zwei Cisco ISR4331 Router (ZBFW-1 und ZBFW-2), welche als #htl3r.full[zbf] konfiguriert wurden. Ein zentraler Bestandteil des Labors ist ein Cisco UCS-Server, der als administrativer Zugangspunkt für die Verwaltung der Netzwerkgeräte dient.

Hinter den Firewalls arbeitet ein Catalyst-Switch als Distribution-Switch (DSW), welcher das Routing zwischen den verschiedenen #htl3r.full[vlan] Segmenten übernimmt. An diesem Switch sind die zwei Access-Switches (ASW-1 und ASW-2) angeschlossen, an denen die Layer-2-Sicherheitsfunktionen wie Port-Security und DHCP Snooping implementiert wurden. Zur zentralen Authentifizierung der Zugriffe wird eine Cisco Identity Services Engine (#htl3r.short[ise]) eingesetzt.

== Virtueller Standort (GNS3)

Neben dem physischen Labor wurde eine vollständig separate Simulationsumgebung in der Software #htl3r.short[gns3] erstellt @gns3-docs. Diese Umgebung besitzt keine direkte Verbindung zum physischen Labor. Es handelt sich um ein eigenständiges System, das ausschließlich für die Entwicklung und Simulation von komplexen Topologien genutzt wird. In dieser Umgebung wird die DiagNet-Applikation betrieben und gegen die simulierten Netzwerkkomponenten getestet.

#figure(
  image("../assets/gns3_topo.png", width: 100%),
  caption: [
    GNS3-Simulationsumgebung
  ],
) <fig-gns3>

Die Simulation war während der gesamten Entwicklungsphase unverzichtbar, da dort Netzwerke mit einer größeren Anzahl an Switches aufgebaut werden konnten, als physisch im Labor zur Verfügung standen. Da DiagNet über das Protokoll #htl3r.full[ssh] respektive Telnet mit den Geräten kommuniziert, ist der Ablauf eines Testfalls identisch, unabhängig davon, ob das Zielgerät physisch vorhanden ist oder in GNS3 simuliert wird.

== Designentscheidungen

Die Entscheidung für eine zentrale Authentifizierung über die ISE wurde getroffen, um die Verwaltung von Administrator-Passwörtern zu vereinfachen. Anstatt Passwörter auf jedem Switch einzeln zu pflegen, ermöglicht dieses Design eine zentrale Änderung, die sofort für alle Geräte im Labor wirksam wird.

Beim Spanning-Tree-Protokoll wurde auf Rapid PVST+ gesetzt. Dieser Standard bietet den Vorteil, dass der Zustand für jedes VLAN separat geprüft werden kann. Dies macht die Auswertung der automatisierten Tests in DiagNet deutlich präziser und erleichtert die Identifizierung von Konfigurationsfehlern in einzelnen Netzwerksegmenten.

== VLAN-Konzept

Das Netzwerk im Labor wurde in vier funktionale Bereiche unterteilt, um eine klare Trennung der Datenströme zu erreichen.

#figure(
  table(
    columns: (auto, auto, 1fr),
    inset: 8pt,
    align: (center, center, left),
    table.header([*VLAN-ID*], [*Name*], [*Zweck*]),
    [10], [CLIENTS-A], [Endgeräte am ersten Access-Switch],
    [20], [CLIENTS-B], [Endgeräte am zweiten Access-Switch],
    [99], [MANAGEMENT], [Verwaltung der Switches über SSH oder Telnet],
    [999], [NATIVE-VLAN], [Native VLAN für ungetaggten Datenverkehr],
  ),
  caption: [Einteilung der VLAN-Segmente im physischen Labor.],
) <tab-vlans>

Der Datenverkehr zwischen den produktiven VLANs wird ausschließlich über den Distribution-Switch geleitet. Die Access-Switches fungieren als reine Layer-2-Geräte. Durch die Nutzung eines dedizierten Native VLANs wurde sichergestellt, dass ungetaggter Datenverkehr nicht unkontrolliert in die produktiven Netze gelangen kann.

#pagebreak()

== IP-Adressierungsschema

Das gewählte Adressschema folgt dem logischen Muster `10.0.VLAN.Host`. Dies ermöglicht es, die Zugehörigkeit eines Geräts zu einem bestimmten Netzwerksegment direkt an der IP-Adresse zu erkennen.

#figure(
  table(
    columns: (auto, auto, auto),
    inset: 8pt,
    align: (center, center, left),
    table.header([*Gerät*], [*IP-Adresse*], [*Funktion*]),
    [DSW], [10.0.99.1], [Distribution-Switch und Gateway für VLAN 99],
    [ASW-1], [10.0.99.2], [Erster Access-Switch im Management-Netz],
    [ASW-2], [10.0.99.3], [Zweiter Access-Switch im Management-Netz],
    [ISE], [10.0.99.10], [Zentraler Server für Authentifizierung],
  ),
  caption: [IP-Adressierung für die Verwaltung der Infrastruktur.],
) <tab-ips>

Über das Management-VLAN greift die DiagNet-Applikation direkt auf diese IP-Adressen zu, um die Testläufe gegen die physischen Geräte durchzuführen.

== Management-Netzwerk und Zugriffsschutz

Das Management-VLAN wurde strikt vom restlichen Datenverkehr getrennt. Dies stellt sicher, dass der administrative Zugriff auf die Geräte auch bei einer hohen Auslastung oder Fehlern im produktiven Netz stabil bleibt. Die Anmeldung erfolgt über SSH in der Version 2 oder alternativ über Telnet.

#htl3r.code(
  caption: [VTY-Konfiguration für SSH- und Telnet-Zugang mit zentraler Authentifizierung],
  description: `switch-config`,
)[
  ```
  line vty 0 15
   transport input ssh telnet
   login authentication SSH_AUTH
  ```
]

Um den Zugriff auch bei einem Ausfall des zentralen RADIUS-Servers sicherzustellen, wurde auf den Geräten ein lokaler Zugang für den Notfall eingerichtet. Dies verhindert, dass man sich im Falle einer Störung der ISE selbst vom System ausschließt.

== Benennung und Trennung der Logik

Die Benennung der Geräte folgt einem funktionalen Schema (z. B. DSW, ASW), welches in der Datenbank von DiagNet als Bezeichner dient. Ein wesentliches Prinzip beim Aufbau war die Trennung zwischen der physikalischen Infrastruktur und der Testlogik. Die Testfälle sind so konzipiert, dass sie unabhängig von der spezifischen Verkabelung funktionieren. Sie verbinden sich mit einer IP-Adresse und prüfen die Konfigurationsparameter, was den Einsatz derselben Testfälle sowohl in der GNS3-Simulation als auch im physischen Labor ermöglicht.
