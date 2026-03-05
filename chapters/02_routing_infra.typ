#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Luka Pacar")
= Routing-Infrastruktur

Die Routing-Infrastruktur ist die Grundlage der gesamten Simulationsumgebung von #htl3r.short[diagnet].
Das Design zielt darauf ab, eine komplexe und heterogene Topologie bereitzustellen, die unterschiedliche Protokoll-Standards und Routing-Protokolle vereint.
Die gesamte virtuelle Infrastruktur basiert dabei auf Cisco-Komponenten, wobei bewusst verschiedene Konfigurationen und Architekturen implementiert wurden, um ein möglichst breites Spektrum an Netzwerk-Verhalten abzubilden.

#figure(
  image("../assets/WAN10.jpg", width: 95%),
  caption: [WAN Topologie],
) <fig-kahn>
== Architektur des WAN
Das Zentrum der Topologie bildet ein simuliertes #htl3r.full[wan], das in vier unabhängige #htl3r.fullpl[as] unterteilt ist.
Jedes dieser Systeme agiert als eigenständiger #htl3r.full[isp].
Der Austausch von Routing-Informationen zwischen den Providern erfolgt über das #htl3r.full[ebgp].


=== Protokoll-Diversität im Backbone
Die Backbones der einzelnen #htl3r.shortpl[isp] sind technisch unterschiedlich aufgebaut, um verschiedene Transport-Mechanismen und #htl3r.fullpl[igp] bereitzustellen:

*ISP 1 (OSPF & MPLS):*
Nutzung von #htl3r.full[ospf] sowie #htl3r.full[mpls].
Das Label Switching erfolgt direkt im Global Routing Table.

*ISP 2 (RIP & GRE):*
Implementierung von #htl3r.short[rip]v2 als Legacy-Protokoll.

*ISP 3 (EIGRP & GRE):*
Verwendung von #htl3r.full[eigrp] zur Routen-Berechnung.
Teilbereiche sind, wie bei #htl3r.short[isp] 2, über #htl3r.full[gre]-Tunnel verbunden, wodurch die #htl3r.short[bgp]-Nachbarn miteinander kommunizieren können.

*ISP 4:*
Fungiert als reines Transit-#htl3r.short[as] zur Kopplung der Provider ohne eigene Backbone-Logik.

=== Pfadmanipulation und Traffic Engineering
Ein zentrales Element des WAN-Designs ist das Traffic Engineering, um Datenströme gezielt zu steuern.
Während das #htl3r.full[bgp] standardmäßig den Pfad mit der geringsten AS-Pfad-Länge bevorzugt, werden in dieser Topologie Attribute manipuliert, um spezifische Routing-Entscheidungen zu erzwingen.

Am Peering-Punkt zwischen `ISP1` und `ISP2` kommt hierfür beispielsweise der #htl3r.full[med] zum Einsatz.
Für ausgewählte Zielnetze wird die Metrik ausgehender Updates künstlich erhöht.
Dies signalisiert dem benachbarten #htl3r.short[as] eine schlechtere Verbindungsgüte für diese spezifischen Präfixe, wodurch der eingehende Traffic auf alternative Links verlagert wird.

Die nachfolgende Konfiguration veranschaulicht diesen Vorgang konkret: Zunächst wird das betroffene Zielnetz über eine #htl3r.full[acl] identifiziert. Anschließend greift eine Route-Map namens `MED`, die genau für dieses Netz den Metrik-Wert auf 200 anhebt. Ein zweiter, leerer Eintrag in der Route-Map stellt sicher, dass alle übrigen Routen unverändert weitergegeben werden. Abschließend wird diese Richtlinie an den BGP-Prozess gebunden und für alle ausgehenden Routing-Updates in Richtung des Nachbarn `60.60.60.2` aktiviert.
#htl3r.code(
  caption: [Konfiguration der Routen-Manipulation mittels #htl3r.short[med]],
  description: `route_map_config`,
)[
  ```cisco
  ! Definition des betroffenen Traffics
  access-list 1 permit 10.10.10.10 0.0.0.255

  ! Setzen einer hohen Metrik (200)
  route-map MED permit 5
   match ip address access-list 1
   set metric 200

  ! Standard-Regel für restlichen Traffic
  route-map MED permit 10

  ! Anwendung auf den BGP-Nachbarn
  router bgp 11
   neighbor 60.60.60.2 route-map MED out
  ```
]

== Standort-Vernetzung und Redundanz
Die angebundenen Netze demonstrieren verschiedene fortgeschrittene Konzepte zur Hochverfügbarkeit und Standortvernetzung, deren primäres Ziel es ist, eine unterbrechungsfreie Kommunikation sicherzustellen und Endgeräte zuverlässig an das WAN anzubinden.

=== Gateway-Redundanz
Zur Absicherung des Default-Gateways für Endgeräte werden zwei unterschiedliche #htl3r.fullpl[fhrp] eingesetzt:

#htl3r.short[hsrp]-Standort:
Hier wird das #htl3r.full[hsrp] verwendet.
Eine virtuelle IP-Adresse wird von einem primären Router bedient, während der zweite Router lediglich den Status überwacht und nur im Fehlerfall übernimmt.

#htl3r.short[glbp]-Standort:
Im Gegensatz dazu nutzt dieser Standort das #htl3r.full[glbp].
Dieses ermöglicht eine aktive Lastverteilung auf Gateway-Ebene.
Mehrere Router leiten gleichzeitig Traffic weiter, indem sie auf #htl3r.full[arp]-Anfragen mit unterschiedlichen virtuellen #htl3r.full[mac]-Adressen antworten.

=== Skalierbare Vernetzung mittels #htl3r.short[dmvpn]
Die Verbindung zwischen den #htl3r.short[hsrp]- und #htl3r.short[glbp]-Standorten wird über #htl3r.full[dmvpn] Phase 3 realisiert.
Technologisch ermöglicht dies den Aufbau einer Hub-and-Spoke-Topologie über die Infrastruktur der #htl3r.shortpl[isp] hinweg.

Ein wesentliches Merkmal der Phase 3 ist die Optimierung des Datenpfads durch #htl3r.full[nhrp]-Redirects.
Initiale Pakete zwischen zwei Außenstellen laufen über den Hub.
Gleichzeitig signalisiert der Hub den beteiligten Routern jedoch, dass eine direktere Verbindung möglich ist.
Daraufhin bauen die Spokes dynamisch einen direkten Tunnel zueinander auf ("Spoke-to-Spoke"), wodurch der Traffic nicht mehr über den zentralen Hub fließt.

Ein Blick auf die Konfiguration des zentralen Hub-Routers zeigt, wie dieses Konzept in der Praxis umgesetzt wird.
Die Basis bildet ein Multipoint-GRE-Tunnel, der alle Außenstellen als eine Art dynamische Sammelstelle anbindet.
Damit die Router über dieses Overlay-Netzwerk auch Routing-Updates austauschen können, erlaubt der Befehl `ip nhrp map multicast dynamic` die gezielte Verteilung von Multicast-Paketen an alle bekannten Spokes.
Die Kernfunktion der Phase 3 wird schließlich mit `ip nhrp redirect` eingeschaltet.
Genau dieser Befehl versetzt den Hub in die Lage, den Außenstellen einen direkteren Pfad mitzuteilen und so den direkten Verbindungsaufbau einzuleiten.

#htl3r.code(
  caption: [Konfiguration des #htl3r.short[dmvpn]-Hubs],
  description: `dmvpn_hub_config`,
)[
  ```cisco
  interface Tunnel0
   ! Konfiguriert Multipoint GRE
   tunnel mode gre multipoint

   ! Erlaubt Multicast-Traffic (z. B. für OSPF) zu den dynamischen Spokes
   ip nhrp map multicast dynamic

   ! Aktiviert DMVPN Phase 3: Hub informiert Spokes über direktere Pfade
   ip nhrp redirect
  ```
]
=== Site-to-Site #htl3r.short[vpn]
Die zwei Standorte `IPSEC` sind über eine klassische Site-to-Site #htl3r.short[vpn]-Verbindung gekoppelt.
Der verschlüsselte Tunnel überspannt das gesamte #htl3r.short[wan].
Die Endpunkte handeln dabei eigenständig die #htl3r.full[ike]-Phase-1 zur Authentifizierung und die #htl3r.short[ike]-Phase-2 zur Verschlüsselung des Nutzdatenverkehrs aus.

== Spezielle Funktionsbereiche
Ergänzend zur reinen Transportfunktion der #htl3r.short[wan]-Infrastruktur integriert die vorliegende Topologie dedizierte Segmente, die gezielt fortgeschrittene Netzwerkdienste wie Adressübersetzung und hierarchisches Routing demonstrieren.

=== #htl3r.full[nat]
Ein spezialisierter Standort bildet die Schnittstelle zwischen privaten Adressen und dem öffentlichen Adressraum ab.
Dabei kommen drei Verfahren des #htl3r.short[nat] zum Einsatz, um unterschiedliche Übersetzungsszenarien zu simulieren:

- *Static #htl3r.short[nat]:*
  Eine feste 1-zu-1-Zuordnung einer öffentlichen IP-Adresse zu einem internen Host.

- *Dynamic #htl3r.short[nat]:*
  Die temporäre Zuweisung einer globalen Adresse aus einem definierten Pool für die Dauer der Kommunikation.

- *Port Address Translation (PAT):*
  Das Multiplexing mehrerer interner Clients über eine einzige öffentliche IP-Adresse unter Verwendung unterschiedlicher Source-Ports.

=== #htl3r.short[ospf] Multi-Area Design
Zur Demonstration hierarchischer Routing-Strukturen wurde ein Standort in mehrere #htl3r.short[ospf]-Areas unterteilt.
Ein zentraler Backbone (Area 0) verbindet dabei untergeordnete Bereiche (Area 1, Area 2) über #htl3r.full[abr].
Dieses Design reduziert die Größe der #htl3r.full[lsdb] auf den einzelnen Routern.

== Fazit zur Routing-Infrastruktur
Zusammenfassend bietet die vorgestellte Topologie weit mehr als nur eine Ansammlung von Routern und Protokollen.
Sie formt ein realitätsnahes Abbild eines komplexen Unternehmensnetzwerks.
Das bewusste Zusammenspiel aus Provider-Netzen, redundanten Standorten und spezialisierten Diensten macht diese Infrastruktur zu einer äußerst vielseitigen Testumgebung.
Genau darin liegt ihr wesentlicher Mehrwert: Sie bietet das perfekte Fundament, um die in #htl3r.short[diagnet] implementierten Testcases praxisnah auszuführen und umfassend zu validieren.
