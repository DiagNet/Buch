#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Luka Pacar")
= Routing-Infrastruktur

Die Routing-Infrastruktur ist die Grundlage der gesamten Simulationsumgebung von #htl3r.short[diagnet].
Das Design zielt darauf ab, eine komplexe und heterogene Topologie bereitzustellen, die unterschiedliche Protokoll-Standards und Routing-Protokolle vereint.
Die gesamte virtuelle Infrastruktur basiert dabei auf Cisco-Komponenten, wobei bewusst verschiedene Konfigurationen und Architekturen implementiert wurden, um ein möglichst breites Spektrum an Netzwerk-Verhalten abzubilden.

== Architektur des Wide Area Networks (WAN)
Das Zentrum der Topologie bildet ein simuliertes #htl3r.full[wan], das in vier unabhängige #htl3r.full[as] unterteilt ist.
Jedes dieser Systeme agiert als eigenständiger Internet Service Provider (ISP).
Der Austausch von Routing-Informationen zwischen den Providern erfolgt über das #htl3r.full[ebgp].

=== Pfadmanipulation und Traffic Engineering
Ein zentrales Element des WAN-Designs ist das gezielte Traffic Engineering, um Datenströme jenseits der Standard-Metriken zu steuern.
Während das #htl3r.full[bgp] standardmäßig den Pfad mit der geringsten AS-Pfad-Länge bevorzugt, werden in dieser Topologie Attribute manipuliert, um spezifische Routing-Entscheidungen zu erzwingen.

Am Peering-Punkt zwischen `ISP1` und `ISP2` kommt hierfür der #htl3r.full[med] zum Einsatz.
Für ausgewählte Zielnetze wird die Metrik ausgehender Updates künstlich erhöht.
Dies signalisiert dem benachbarten AS eine schlechtere Verbindungsgüte für diese spezifischen Präfixe, wodurch der eingehende Traffic auf alternative Links verlagert wird.

#htl3r.code(
  caption: [Konfiguration der Routen-Manipulation mittels MED],
  description: `route_map_config`,
)[
  ```cisco
  ! Definition des betroffenen Traffics
  access-list 1 permit 10.10.10.10 0.0.0.255

  ! Setzen einer künstlich hohen Metrik (200)
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

=== Protokoll-Diversität im Backbone
Die Backbones der einzelnen ISPs sind technisch unterschiedlich aufgebaut, um verschiedene Transport-Mechanismen und #htl3r.fullpl[igp] bereitzustellen:

*ISP 1 (OSPF & MPLS):*
Nutzung von #htl3r.short[ospf] sowie #htl3r.full[mpls].
Das Label Switching erfolgt direkt im Global Routing Table ohne L3VPN-Overlay.

*ISP 2 (RIP & GRE):*
Implementierung von #htl3r.short[rip]v2 als Legacy-Protokoll.

*ISP 3 (EIGRP & GRE):*
Verwendung von #htl3r.short[eigrp] zur Routen-Berechnung.
Teilbereiche sind, wie bei ISP 2, über #htl3r.short[gre]-Tunnel verbunden, wodurch die BGP-Nachbarn miteinander kommunizieren können.

*ISP 4:*
Fungiert als reines Transit-AS zur Kopplung der Provider ohne eigene Backbone-Logik.

== Standort-Vernetzung und Redundanz
Die angebundenen Netze demonstrieren verschiedene Konzepte zur Hochverfügbarkeit und Standortvernetzung.

=== Gateway-Redundanz (FHRP)
Zur Absicherung des Default-Gateways für Endgeräte werden zwei unterschiedliche #htl3r.fullpl[fhrp] eingesetzt:

HSRP-Standort:
Hier wird das #htl3r.full[hsrp] verwendet.
Eine virtuelle IP-Adresse wird von einem primären Router bedient, während der zweite Router lediglich den Status überwacht und nur im Fehlerfall übernimmt.

GLBP-Standort:
Im Gegensatz dazu nutzt dieser Standort das #htl3r.full[glbp].
Dieses ermöglicht eine aktive Lastverteilung auf Gateway-Ebene.
Mehrere Router leiten gleichzeitig Traffic weiter, indem sie auf ARP-Anfragen mit unterschiedlichen virtuellen MAC-Adressen antworten.

=== Skalierbare Vernetzung mittels DMVPN
Die Verbindung zwischen den HSRP- und GLBP-Standorten wird über #htl3r.full[dmvpn] Phase 3 realisiert.
Technologisch ermöglicht dies den Aufbau einer Hub-and-Spoke-Topologie über die Infrastruktur der ISPs hinweg.

Ein wesentliches Merkmal der Phase 3 ist die Optimierung des Datenpfads durch #htl3r.full[nhrp]-Redirects.
Initiale Pakete zwischen zwei Außenstellen laufen über den Hub.
Gleichzeitig signalisiert der Hub den beteiligten Routern jedoch, dass eine direktere Verbindung möglich ist.
Daraufhin bauen die Spokes dynamisch einen direkten Tunnel zueinander auf ("Spoke-to-Spoke"), wodurch der Traffic nicht mehr über den zentralen Hub fließt.

== Spezielle Funktionsbereiche
Ergänzend zur WAN-Infrastruktur beinhaltet die Topologie dedizierte Segmente für Adressübersetzung und hierarchisches Routing.

=== Network Address Translation (NAT)
Ein spezialisierter Standort bildet die Schnittstelle zwischen privaten Addressen und dem öffentlichen Adressraum ab.
Dabei kommen drei Verfahren des #htl3r.full[nat] parallel zum Einsatz, um unterschiedliche Übersetzungsszenarien zu simulieren:

- *Static NAT:*
  Eine feste 1-zu-1-Zuordnung einer öffentlichen IP-Adresse zu einem internen Host.

- *Dynamic NAT:*
  Die temporäre Zuweisung einer globalen Adresse aus einem definierten Pool für die Dauer der Kommunikation.

- *Port Address Translation (PAT):*
  Das Multiplexing mehrerer interner Clients über eine einzige öffentliche IP-Adresse unter Verwendung unterschiedlicher Source-Ports (Port Address Translation).

=== OSPF Multi-Area Design
Zur Demonstration hierarchischer Routing-Strukturen wurde ein Standort in mehrere #htl3r.short[ospf]-Areas unterteilt.
Ein zentraler Backbone (Area 0) verbindet dabei untergeordnete Bereiche (Area 1, Area 2) über Area Border Router (ABR).
Dieses Design reduziert die Größe der Link-State-Datenbank (LSDB) auf den einzelnen Routern.

=== Site-to-Site VPN
Die Standorte IPSEC1 und IPSEC2 sind über eine klassische Site-to-Site VPN-Verbindung gekoppelt.
Der verschlüsselte Tunnel überspannt das gesamte WAN.
Die Endpunkte handlen dabei eigenständig die IKE-Phase-1 zur Authentifizierung und die IKE-Phase-2 zur Verschlüsselung des Nutzdatenverkehrs aus.

