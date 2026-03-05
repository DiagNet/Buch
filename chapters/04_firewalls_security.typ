#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Benedikt Theuretzbachner")
== Firewalls & Perimetersicherheit

In modernen Netzwerkinfrastrukturen spielen Firewalls eine zentrale Rolle beim Schutz von Systemen und Daten. Sie kontrollieren den Datenverkehr zwischen verschiedenen Netzwerksegmenten und stellen sicher, dass nur definierte und erlaubte Verbindungen zugelassen werden. Dadurch können unautorisierte Zugriffe verhindert und potenzielle Sicherheitsrisiken reduziert werden.

Im Rahmen dieses Projekts wird eine Sicherheitsarchitektur implementiert, welche die beiden Standorte der Testumgebung voneinander trennt und gleichzeitig eine sichere Kommunikation ermöglicht. Dabei kommen unterschiedliche Firewall-Technologien zum Einsatz, die jeweils spezifische Aufgaben innerhalb der Infrastruktur erfüllen.

Der virtuelle Standort wird durch eine FortiGate-Firewall abgesichert, während der zweite Standort durch Cisco Firewalls mit einer Zone-Based Firewall (ZBFW) geschützt wird. Die Kommunikation zwischen den beiden Standorten erfolgt über einen verschlüsselten Site-to-Site-VPN-Tunnel auf Basis von IKEv2 und IPsec.

Die Sicherheitsarchitektur verfolgt dabei folgende Ziele:

- Schutz der internen Netzwerke vor unautorisierten Zugriffen
- sichere Verbindung der beiden Standorte über ein verschlüsseltes VPN
- Bereitstellung einer realistischen Testumgebung für Netzwerk- und Sicherheitstests

=== Virtuelle FortiGate Infrastruktur
Der virtuelle Standort der Testumgebung wird durch eine FortiGate-Firewall abgesichert. Dieser Standort ist vollständig virtualisiert und wird innerhalb der vSphere-Umgebung betrieben. Die einzelnen Netzwerke werden dabei als Port Groups umgesetzt und logisch voneinander getrennt.

Innerhalb dieses Standorts existieren zwei Subnetze mit unterschiedlichen Aufgaben.

Das erste Subnetz beinhaltet einen Rocky Linux Server, auf dem eine Nextcloud-Instanz betrieben wird. Diese dient als Beispiel für einen öffentlich erreichbaren Dienst innerhalb der Infrastruktur. Um den Zugriff aus externen Netzwerken zu ermöglichen, wird auf der FortiGate-Firewall ein Port Forwarding eingerichtet. Dabei wird ein Virtual IP (VIP) Objekt verwendet, das eingehende Verbindungen von der externen Adresse auf die interne IP-Adresse des Servers weiterleitet.

Im zweiten Subnetz befinden sich ein Windows 11 Client sowie ein weiterer Rocky Linux Server. Der Windows Client dient hauptsächlich für Test- und Validierungszwecke innerhalb der Netzwerkumgebung. Auf dem zweiten Rocky Linux System läuft die DiagNet-Applikation, welche die automatisierten Netzwerktests ausführt.

Für dieses Subnetz übernimmt die FortiGate zusätzlich die Rolle eines DHCP-Servers. Dadurch können Clients innerhalb dieses Netzwerks automatisch eine IP-Adresse sowie weitere Netzwerkkonfigurationsparameter beziehen.

Über den aufgebauten VPN-Tunnel zwischen den beiden Standorten kann die DiagNet-Instanz auf die Geräte des zweiten Standorts zugreifen. Dadurch ist es möglich, automatisierte Tests gegen die dort befindlichen Netzwerkgeräte durchzuführen und deren Zustand zu überprüfen.

=== Cisco Zone-Based Firewall Instanzen

Der zweite Standort der Testumgebung wird durch zwei physische Cisco Router des Typs ISR4331 abgesichert. Beide Geräte verfügen über eine aktivierte SecurityK9-Lizenz, wodurch erweiterte Sicherheitsfunktionen wie die Zone-Based Firewall (ZBF) sowie IPsec-VPN unterstützt werden.

Die beiden Router arbeiten gemeinsam als Gateway für das interne Netzwerk. Zu diesem Zweck wird das Gateway Load Balancing Protocol (GLBP) eingesetzt. Dadurch stellen beide Geräte eine gemeinsame virtuelle Gateway-Adresse bereit, über die Clients im internen Netzwerk ihr Standard-Gateway erreichen. Neben der Lastverteilung erhöht dieses Verfahren auch die Ausfallsicherheit, da beim Ausfall eines Geräts der verbleibende Router weiterhin als Gateway fungieren kann.

Auf beiden Routern ist eine Zone-Based Firewall implementiert. Netzwerkinterfaces werden dabei bestimmten Sicherheitszonen zugeordnet. Der Datenverkehr zwischen diesen Zonen wird anschließend durch definierte Firewall-Policies kontrolliert.

In der implementierten Architektur werden drei Zonen verwendet:

- INSIDE
- OUTSIDE
- self

Die Zone INSIDE repräsentiert das interne Netzwerk des Standorts, während die Zone OUTSIDE den externen Netzwerkbereich darstellt. Die Zone self beschreibt den Router selbst und wird verwendet, um den Zugriff auf Management- oder Steuerprotokolle zu regulieren.

Der IPsec-VPN-Tunnel zum virtuellen Standort wird über den Router *zbfw-1* aufgebaut. Damit der Aufbau und Betrieb des VPN-Tunnels durch die Firewall nicht blockiert wird, muss entsprechender VPN-Verkehr explizit erlaubt werden. Dazu werden innerhalb der Zone-Based Firewall passende Klassen definiert, welche die für IPsec notwendigen Protokolle erkennen und zulassen.

Der folgende Konfigurationsauszug zeigt die Definition der entsprechenden Access List sowie der zugehörigen Class Map zur Erkennung des VPN-Verkehrs:

```cisco
ip access-list extended VPN-ESP
  permit esp any any

class-map type inspect match-any VPN-CLASS
 match protocol isakmp
 match protocol ipsec
 match access-group name VPN-ESP
 exit
```
Erklärung:
- Access-List `VPN-ESP`: Erfasst das Protokoll ESP, welches für die Verschlüsselung der Nutzdaten zuständig ist.
- Class-Map `VPN-CLASS`: Behandelt verschiedenen Traffic. Durch `match-any` wird Verkehr als VPN klassifiziert, wenn er entweder dem Verbindungsaufbau (ISAKMP), der VPN-Aushandlung (IPsec) oder der definierten ACL entspricht.

Die Firewall-Engine erkennt ISAKMP und IPsec meist problemlos als Protokoll-Signaturen, da es sich um Standard-UDP-Verbindungen handelt.
ESP ist kein TCP- oder UDP-Protokoll, sondern ein eigenständiges IP-Protokoll mit der Nummer 50. Viele ältere Implementierungen der ZBF-Inspektion erkennen ESP nicht zuverlässig, weswegen für diesen Zweck eine zusätzliche ACL erstellt wurde.
