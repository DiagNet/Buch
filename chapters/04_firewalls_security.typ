#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Benedikt Theuretzbachner")
== Firewalls & Perimetersicherheit

In modernen Netzwerkinfrastrukturen spielen Firewalls eine zentrale Rolle beim Schutz von Systemen und Daten. Sie kontrollieren den Datenverkehr zwischen verschiedenen Netzwerksegmenten und stellen sicher, dass nur definierte und erlaubte Verbindungen zugelassen werden. Dadurch können unautorisierte Zugriffe verhindert und potenzielle Sicherheitsrisiken reduziert werden.

Im Rahmen dieses Projekts wird eine Sicherheitsarchitektur implementiert, welche die beiden Standorte der Testumgebung voneinander trennt und gleichzeitig eine sichere Kommunikation ermöglicht. Dabei kommen unterschiedliche Firewall-Technologien zum Einsatz, die jeweils spezifische Aufgaben innerhalb der Infrastruktur erfüllen.

Der virtuelle Standort wird durch eine FortiGate-Firewall abgesichert, während der zweite Standort durch Cisco Firewalls mit einer #htl3r.long[zbf] geschützt wird. Die Kommunikation zwischen den beiden Standorten erfolgt über einen verschlüsselten #htl3r.long[site_to_site_vpn]-#htl3r.long[vpn_tunnel] auf Basis von #htl3r.short[ikev2] und #htl3r.short[ipsec].

Die Sicherheitsarchitektur verfolgt dabei folgende Ziele:

- Schutz der internen Netzwerke vor unautorisierten Zugriffen
- sichere Verbindung der beiden Standorte über ein verschlüsseltes #htl3r.short[vpn]
- Bereitstellung einer realistischen Testumgebung für Netzwerk- und Sicherheitstests

=== Virtuelle FortiGate Infrastruktur
Der virtuelle Standort der Testumgebung wird durch eine FortiGate-Firewall abgesichert. Dieser Standort ist vollständig virtualisiert und wird innerhalb der #htl3r.long[vsphere]-Umgebung betrieben. Die einzelnen Netzwerke werden dabei als #htl3r.long[port_group]s umgesetzt und logisch voneinander getrennt.

Innerhalb dieses Standorts existieren zwei Subnetze mit unterschiedlichen Aufgaben.

Das erste Subnetz beinhaltet einen Rocky Linux Server, auf dem eine #htl3r.long[nextcloud]-Instanz betrieben wird. Diese dient als Beispiel für einen öffentlich erreichbaren Dienst innerhalb der Infrastruktur. Um den Zugriff aus externen Netzwerken zu ermöglichen, wird auf der FortiGate-Firewall ein #htl3r.long[port_forwarding] eingerichtet. Dabei wird ein #htl3r.long[vip]-Objekt verwendet, das eingehende Verbindungen von der externen Adresse auf die interne IP-Adresse des Servers weiterleitet.

Im zweiten Subnetz befinden sich ein Windows 11 Client sowie ein weiterer Rocky Linux Server. Der Windows Client dient hauptsächlich für Test- und Validierungszwecke innerhalb der Netzwerkumgebung. Auf dem zweiten Rocky Linux System läuft die DiagNet-Applikation, welche die automatisierten Netzwerktests ausführt.

Für dieses Subnetz übernimmt die FortiGate zusätzlich die Rolle eines DHCP-Servers. Dadurch können Clients innerhalb dieses Netzwerks automatisch eine IP-Adresse sowie weitere Netzwerkkonfigurationsparameter beziehen.

Über den aufgebauten #htl3r.long[vpn_tunnel] zwischen den beiden Standorten kann die DiagNet-Instanz auf die Geräte des zweiten Standorts zugreifen. Dadurch ist es möglich, automatisierte Tests gegen die dort befindlichen Netzwerkgeräte durchzuführen und deren Zustand zu überprüfen.

=== Cisco Zone-Based Firewall Instanzen

Der zweite Standort der Testumgebung wird durch zwei physische Cisco Router des Typs ISR4331 abgesichert. Beide Geräte verfügen über eine aktivierte SecurityK9-Lizenz, wodurch erweiterte Sicherheitsfunktionen wie die #htl3r.long[zbf] sowie #htl3r.short[ipsec]-#htl3r.short[vpn] unterstützt werden.

Die beiden Router arbeiten gemeinsam als Gateway für das interne Netzwerk. Zu diesem Zweck wird das #htl3r.short[glbp] eingesetzt. Dadurch stellen beide Geräte eine gemeinsame virtuelle Gateway-Adresse bereit, über die Clients im internen Netzwerk ihr Standard-Gateway erreichen. Neben der Lastverteilung erhöht dieses Verfahren auch die Ausfallsicherheit, da beim Ausfall eines Geräts der verbleibende Router weiterhin als Gateway fungieren kann.

Auf beiden Routern ist eine #htl3r.long[zbf] implementiert. Netzwerkinterfaces werden dabei bestimmten #htl3r.long[sicherheitszone]n zugeordnet. Der Datenverkehr zwischen diesen Zonen wird anschließend durch definierte #htl3r.long[firewall_policy]s kontrolliert.

In der implementierten Architektur werden drei Zonen verwendet:

- INSIDE
- OUTSIDE
- self

Die Zone INSIDE repräsentiert das interne Netzwerk des Standorts, während die Zone OUTSIDE den externen Netzwerkbereich darstellt. Die Zone self beschreibt den Router selbst und wird verwendet, um den Zugriff auf Management- oder Steuerprotokolle zu regulieren.

Der #htl3r.short[ipsec]-#htl3r.long[vpn_tunnel] zum virtuellen Standort wird über den Router zbfw-1 aufgebaut. Damit der Aufbau und Betrieb des #htl3r.long[vpn_tunnel]s durch die Firewall nicht blockiert wird, muss entsprechender #htl3r.short[vpn]-Verkehr explizit erlaubt werden. Dazu werden innerhalb der #htl3r.long[zbf] passende Klassen definiert, welche die für #htl3r.short[ipsec] notwendigen Protokolle erkennen und zulassen.

Der folgende Konfigurationsauszug zeigt die Definition der entsprechenden #htl3r.long[acl] sowie der zugehörigen #htl3r.long[class_map] zur Erkennung des VPN-Verkehrs:

#htl3r.code(
  caption: [Auszug aus der Firewall Konfiguration],
  description: `Cisco IOS Script`,
)[
  ```cisco
  ip access-list extended VPN-ESP
    permit esp any any

  class-map type inspect match-any VPN-CLASS
   match protocol isakmp
   match protocol ipsec
   match access-group name VPN-ESP
   exit
  ```
]

Erklärung:
- #htl3r.long[acl] `VPN-ESP`: Erfasst das Protokoll #htl3r.short[esp], welches für die Verschlüsselung der Nutzdaten zuständig ist.
- #htl3r.long[class_map] `VPN-CLASS`: Behandelt verschiedenen Traffic. Durch `match-any` wird Verkehr als #htl3r.short[vpn] klassifiziert, wenn er entweder dem Verbindungsaufbau (#htl3r.short[isakmp]), der VPN-Aushandlung (#htl3r.short[ipsec]) oder der definierten ACL entspricht.

Die Firewall-Engine erkennt #htl3r.short[isakmp] und #htl3r.short[ipsec] meist problemlos als Protokoll-Signaturen, da es sich um Standard-#htl3r.short[udp]-Verbindungen handelt. #htl3r.short[isakmp] bzw. IKE verwendet #htl3r.short[udp] Port 500 für den Aufbau des Tunnels sowie für den Schlüsselaustausch.

#htl3r.short[esp] hingegen ist kein TCP- oder #htl3r.short[udp]-Protokoll, sondern ein eigenständiges IP-Protokoll mit der Nummer 50. Da dieses Format keine Ports verwendet, kann es von vielen Firewall-Mechanismen nicht so einfach über klassische Portmerkmale identifiziert werden.

In der Praxis kommt zusätzlich häufig #htl3r.short[nat] zwischen den VPN-Endpunkten zum Einsatz. Klassisches #htl3r.short[esp] ist dafür nur eingeschränkt geeignet, da NAT-Geräte üblicherweise Verbindungen anhand von TCP- oder UDP-Portinformationen zuordnen. Da #htl3r.short[esp] keine solchen Felder besitzt, können manche Implementierungen den Datenstrom nicht korrekt behandeln.

Zur Umgehung dieses Problems wird häufig #htl3r.long[nat_traversal] (#htl3r.short[nat_traversal]) eingesetzt. Erkennt IKE während dem Verbindungsaufbau ein NAT-Gerät im Übertragungsweg, werden die ESP-Pakete in #htl3r.short[udp] gekapselt und anschließend über UDP Port 4500 transportiert. Für die Firewall erscheint der verschlüsselte Datenstrom in diesem Fall daher als gewöhnlicher UDP-Verkehr.

In Umgebungen ohne NAT oder wenn NAT-T nicht aktiv ist, wird jedoch weiterhin natives #htl3r.short[esp] (IP-Protokoll 50) verwendet. Genau hier liegt die Schwierigkeit: Einige ältere Implementierungen der ZBF-Inspektion erkennen dieses Format nicht zuverlässig über ihre integrierten Protokoll-Signaturen.

Aus diesem Grund wird zusätzlich eine explizite ACL definiert, die #htl3r.short[esp] direkt anhand der IP-Protokollnummer 50 matcht. Die #htl3r.long[acl] `VPN-ESP` stellt somit sicher, dass auch solcher Datenverkehr korrekt der VPN-Klasse zugeordnet wird und von der Firewall entsprechend verarbeitet werden kann.

=== IKEv2 Site-to-Site VPN

Um eine sichere Kommunikation zwischen den beiden Standorten zu ermöglichen, wird ein verschlüsselter #htl3r.long[site_to_site_vpn]-#htl3r.long[vpn_tunnel] eingesetzt. Dieser verbindet die FortiGate-Firewall des virtuellen Standorts mit dem Cisco Gerät ZBFW-1 des physischen Standorts. Wie bereits erwähnt, basiert der Tunnel auf dem Protokoll #htl3r.short[ikev2] in Kombination mit #htl3r.short[ipsec].

#htl3r.short[ikev2] stellt einen modernen Mechanismus zum Aufbau und zur Verwaltung von #htl3r.short[ipsec]-Tunneln dar. Im Vergleich zu IKEv1 bietet es eine effizientere Aushandlung der Sicherheitsparameter, eine verbesserte Stabilität sowie eine geringere Anzahl an Nachrichten während des Tunnelaufbaus. Dadurch eignet sich #htl3r.short[ikev2] besonders für stabile und langfristige Standortverbindungen.

Der Aufbau eines solchen #htl3r.short[ipsec]-Tunnels erfolgt grundsätzlich in zwei Phasen.

*Phase 1 – IKE Security Association:*

In der ersten Phase wird eine sogenannte IKE Security Association (IKE SA) aufgebaut. In diesem Schritt authentifizieren sich die beiden VPN-Endpunkte gegenseitig und handeln kryptographische Parameter aus, die für die weitere Kommunikation verwendet werden. Zusätzlich wird ein sicherer Kanal etabliert, über den die zweite Phase ausgehandelt wird.

In der implementierten Konfiguration werden folgende Parameter verwendet:

- Verschlüsselung: AES-256
- Integrität: SHA-256
- Diffie-Hellman Gruppe: 14
- Authentifizierung: Pre-Shared Key

AES-256 sorgt für eine starke symmetrische Verschlüsselung des Datenverkehrs, während SHA-256 zur Sicherstellung der Datenintegrität eingesetzt wird. Die Diffie-Hellman Gruppe 14 ermöglicht den Austausch der kryptographischen Schlüssel während der Aushandlung. Sie bietet ein höheres Sicherheitsniveau als veraltete Gruppen wie 1, 2 oder 5 und ist dabei weniger Hardware intensiv als die Gruppen 19 oder 21.

*Phase 2 – IPsec Security Association:*

In der zweiten Phase wird die eigentliche #htl3r.short[ipsec] Security Association (IPsec SA) erstellt. Hier werden die Parameter für den verschlüsselten Datentunnel definiert. Dazu gehören insbesondere die zu schützenden Netzwerke sowie die verwendeten Verschlüsselungsalgorithmen.

Im Rahmen des Projekts werden zwei interne Netzwerke des Cisco-Standorts über den Tunnel erreichbar gemacht. Dadurch kann die DiagNet-Instanz im virtuellen Standort auf Geräte im entfernten Netzwerk zugreifen und entsprechende Tests durchführen.

Die folgenden Subnetze werden über den Tunnel miteinander verbunden:

- 192.168.2.0/24 (DiagNet Standort)
- 10.0.10.0/24 (Testnetzwerk)
- 10.0.99.0/24 (Managementnetzwerk)

=== Implementierung auf der FortiGate

Die FortiGate-Firewall verwendet ein route-based VPN. Dabei wird der #htl3r.long[vpn_tunnel] als eigenes logisches Interface im System angelegt. Über statische Routen kann anschließend festgelegt werden, welche Netzwerke über dieses Interface erreichbar sind.

Der folgende Auszug zeigt die Definition der IKE Phase 1 sowie der zugehörigen Phase 2 Parameter:

#htl3r.code(
  caption: [Auszug aus VPN Konfiguration: `phase1-interface`],
  description: `FortiGate Script`,
)[
  ```
  config vpn ipsec phase1-interface
      edit "FGT-CISCO"
          set interface "port2"
          set ike-version 2
          set proposal aes256-sha256
          set dhgrp 14
          set remote-gw 10.60.90.1
          set psksecret MeinGeheimerKey123
      next
  end
  ```]

Die Phase-2-Definition legt fest, welche internen Netzwerke über den Tunnel erreichbar sind:

#htl3r.code(
  caption: [Auszug aus VPN Konfiguration: `phase2-interface`],
  description: `FortiGate Script`,
)[
  ```
  config vpn ipsec phase2-interface
      edit "FGT-CISCO-P2"
          set phase1name "FGT-CISCO"
          set proposal aes256-sha256
          set dhgrp 14
          set src-subnet 192.168.2.0 255.255.255.0
          set dst-subnet 10.0.10.0 255.255.255.0
      next
  end
  ```]

Der Zugriff zwischen dem lokalen Netzwerk und dem #htl3r.long[vpn_tunnel] wird anschließend über #htl3r.long[firewall_policy]s erlaubt.

=== Implementierung auf dem Cisco Router

Der Cisco Router verwendet eine policy-based VPN-Konfiguration. Dabei wird der Tunnel über eine Crypto Map definiert, welche auf ein Interface angewendet wird. Der zu verschlüsselnde Datenverkehr wird mithilfe einer #htl3r.long[acl] festgelegt.

Die grundlegenden Parameter für #htl3r.short[ikev2] werden im folgenden Beispiel definiert:

#htl3r.code(
  caption: [Auszug aus VPN Konfiguration: `ikev2 proposal`],
  description: `Cisco IOS Script`,
)[
  ```
  crypto ikev2 proposal FGT-PROP
   encryption aes-cbc-256
   integrity sha256
   group 14
  ```]

Die zu verschlüsselnden Netzwerke werden über eine #htl3r.long[acl] bestimmt:

#htl3r.code(
  caption: [Auszug aus VPN Konfiguration: `FGT-ACL`],
  description: `Cisco IOS Script`,
)[
  ```
  ip access-list extended FGT-ACL
   permit ip 10.0.10.0 0.0.0.255 192.168.2.0 0.0.0.255
   permit ip 10.0.99.0 0.0.0.255 192.168.2.0 0.0.0.255
  ```]

Diese #htl3r.long[acl] wird anschließend in einer Crypto Map bekanntgegeben, welche auf dem externen Interface des Routers aktiviert wird.

Durch diese Konfiguration wird der Datenverkehr zwischen den definierten Netzwerken automatisch über den #htl3r.short[ipsec]-#htl3r.long[vpn_tunnel] verschlüsselt übertragen.

=== Zusammenfassung

In diesem Kapitel wurde die Absicherung der beiden Standorte durch unterschiedliche Firewall-Technologien beschrieben. Der virtuelle Standort wird durch eine FortiGate-Firewall geschützt, während am physischen Standort zwei Cisco ISR4331 Router mit aktivierter #htl3r.long[zbf] eingesetzt werden. Zwischen beiden Standorten wurde ein #htl3r.short[ikev2]-basierter #htl3r.short[ipsec]-#htl3r.long[vpn_tunnel] aufgebaut, welcher eine verschlüsselte Kommunikation zwischen den jeweiligen Netzsegmenten ermöglicht. Durch definierte #htl3r.long[sicherheitszone]n, #htl3r.long[firewall_policy]s sowie gezielte Freigaben für den VPN-Traffic wird sichergestellt, dass nur gewünschte Verbindungen zugelassen werden.

Diese Infrastruktur bildet die Grundlage dafür, dass die DiagNet-Instanz Geräte am entfernten Standort über den #htl3r.long[vpn_tunnel] erreichen und automatisierte Netzwerktests durchführen kann.
