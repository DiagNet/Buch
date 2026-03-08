#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Danijel Stamenkovic")
== Switching & Layer 2 <switching_infra>

Bei der Planung der Layer-2-Ebene für die DiagNet-Infrastruktur wurde sich an Standards orientiert, wie sie auch in modernen Firmennetzen zum Einsatz kommen. Es wurde kein rein theoretisches Modell entworfen, sondern es wurden Funktionen gewählt, die in der täglichen Praxis eine hohe Relevanz besitzen und sich automatisiert prüfen lassen. Diese Konfiguration wurde identisch auf den physischen Switches im Labor sowie in der GNS3-Simulationsumgebung umgesetzt, damit eine einheitliche Basis für alle Tests vorhanden ist. Die verschiedenen Funktionen bauen logisch aufeinander auf, was man bei der Fehlersuche immer im Hinterkopf behalten sollte.

=== Spanning Tree mit Rapid PVST+

In jedem geswitchten Netzwerk mit redundanten Wegen wird ein Protokoll benötigt, das Schleifen verhindert. Ohne einen solchen Schutz würden Broadcast-Stürme das Netz innerhalb kürzester Zeit lahmlegen. Hierfür wird das #htl3r.full[stp] eingesetzt, welches redundante Verbindungen logisch sperrt und sie erst dann freischaltet, wenn der primäre Pfad ausfällt.

In der DiagNet-Infrastruktur wird die Variante #htl3r.full[pvst] genutzt @cisco-stp-pvst. Bei diesem Standard lässt Cisco für jedes VLAN eine eigene Instanz des Spanning Tree laufen, wodurch man den Datenverkehr über verschiedene Uplinks verteilen kann. Der Distribution-Switch wurde dabei fest als Root-Bridge definiert, da dieser den zentralen Punkt im Netzwerk bildet. Dies wurde über die Bridge-Priority gelöst, indem man den Befehl `root primary` verwendet hat, was dem Switch die Priorität 24576 zuweist.

```
spanning-tree mode rapid-pvst
spanning-tree vlan 1-4094 root primary
```

#pagebreak()

An den Ports, an denen Endgeräte angeschlossen sind, wurde die Funktion _PortFast_ aktiviert. Normalerweise müsste man bis zu 30 Sekunden warten, bis ein Port Daten senden darf, was durch PortFast umgangen wird. Damit jedoch kein fremder Switch an so einen Port gesteckt werden kann, ist gleichzeitig der _#htl3r.full[bpdu] Guard_ aktiv. Sobald ein BPDU-Paket an einem solchen Port empfangen wird, schaltet der Switch diesen sofort ab.

```
interface range GigabitEthernet0/3 - 24
 spanning-tree portfast
 spanning-tree bpduguard enable
```

=== Höhere Bandbreite durch EtherChannel

Einzelne Gigabit-Verbindungen zwischen den Switches könnten bei viel Datenverkehr schnell zum Engpass werden. Deshalb nutzt man #htl3r.full[lacp], um mehrere physische Leitungen zu einem logischen Kanal zu bündeln. Dies bringt nicht nur mehr Geschwindigkeit, sondern sorgt auch für eine höhere Ausfallsicherheit, da beim Riss eines Kabels die anderen Leitungen den Verkehr sofort übernehmen.

Die Konfiguration wurde mit dem Parameter `mode active` durchgeführt. Das bedeutet, dass der Switch von sich aus versucht, den Kanal mit der Gegenseite auszuhandeln. So stellt man sicher, dass der EtherChannel stabil aufgebaut wird, egal welches Gerät zuerst eingeschaltet wird.

```
interface range GigabitEthernet0/1 - 2
 channel-group 1 mode active

interface Port-channel1
 switchport mode trunk
 switchport trunk native vlan 999
```

Damit die Datenpakete gleichmäßig auf die verfügbaren Leitungen verteilt werden, kommt der `src-dst-mac`-Algorithmus zum Einsatz. Der Switch entscheidet anhand der MAC-Adressen von Sender und Empfänger, über welches Kabel die Daten geschickt werden, damit die Reihenfolge der Pakete innerhalb einer Verbindung erhalten bleibt.

=== VLAN-Verwaltung mit VTP und DTP

Damit man nicht auf jedem einzelnen Switch manuell alle VLANs anlegen muss, wird das #htl3r.full[vtp] in der Version 2 verwendet. Die Domain trägt den Namen `DIAGNET`. Der Distribution-Switch arbeitet hierbei als Server, während die Access-Switches als Clients konfiguriert wurden. So werden Änderungen an der VLAN-Struktur automatisch im ganzen Netz verteilt, was Zeit spart und Tippfehler verhindert.

Beim Trunking wurde das Protokoll #htl3r.full[dtp] auf allen Leitungen komplett abgeschaltet. Man möchte nicht, dass ein Port von sich aus entscheidet, ob er zu einem Trunk wird oder nicht. Mit dem Befehl `switchport nonegotiate` wird dieser Zustand festgeschrieben. Dies ist eine wichtige Maßnahme gegen Angriffe, bei denen jemand versucht, unerlaubt Zugriff auf andere VLANs zu erhalten.

```
interface GigabitEthernet0/24
 switchport mode trunk
 switchport nonegotiate
 switchport trunk native vlan 999
 switchport trunk allowed vlan 10,20,99,999
```

=== DHCP Snooping als Schutzmaßnahme

Das Protokoll #htl3r.short[dhcp] ist oft ein Ziel für Angriffe. Ein Angreifer könnte einen eigenen Server ins Netz hängen, um den Datenverkehr über sich umzuleiten. Um das zu verhindern, wird DHCP Snooping eingesetzt. Dabei legt man fest, welchen Ports man vertraut und welchen nicht.

Nur die Uplinks zum Distribution-Switch wurden als vertrauenswürdig markiert. Wenn an einem normalen Port für Endgeräte eine Antwort von einem DHCP-Server ankommt, wird diese vom Switch sofort verworfen @cisco-layer2-security.

#pagebreak()

```
ip dhcp snooping
ip dhcp snooping vlan 10,20,99

interface GigabitEthernet0/24
 ip dhcp snooping trust
```

Durch das Snooping baut der Switch zudem eine Tabelle auf, in der die Zuweisungen von IP-Adressen zu MAC-Adressen gespeichert sind. Diese Informationen sind die Grundlage für weitere Sicherheitsprüfungen im Netzwerk.

=== Überprüfung mit Dynamic ARP Inspection

Das Protokoll #htl3r.full[arp] hat von Haus aus keine Sicherheitsfunktionen, was Angriffe wie das ARP-Spoofing ermöglicht. Hierbei werden gefälschte Nachrichten verschickt, um Daten abzufangen. Zur Abwehr nutzt man #htl3r.full[dai], welche jedes eingehende Paket gegen die Tabelle aus dem DHCP Snooping prüft.

Passt die Kombination aus IP und MAC nicht zu den gespeicherten Daten, wird das Paket gelöscht. Wie beim Snooping werden auch hier nur die Uplink-Ports als vertrauenswürdig eingestuft.

```
ip arp inspection vlan 10,20,99

interface GigabitEthernet0/24
 ip arp inspection trust
```

#pagebreak()

=== Sicherheit am Port durch Port Security

Auf jedem Port für Endgeräte wurde Port Security aktiviert. Man erlaubt dabei genau eine MAC-Adresse pro Port, welche der Switch beim ersten Kontakt automatisch lernt und in der Konfiguration speichert.

```
switchport port-security
switchport port-security maximum 1
switchport port-security violation shutdown
switchport port-security mac-address sticky
```

Falls ein Verstoß erkannt wird, schaltet der Switch den Port sofort ab. Damit man bei Fehlern nicht jedes Mal manuell eingreifen muss, wurde eine automatische Wiederherstellung nach 300 Sekunden konfiguriert.

=== Schutz vor Broadcast-Überflutung mit Storm Control

In einem geswitchten Netz kann es passieren, dass ein einzelnes Gerät oder eine fehlerhafte Konfiguration plötzlich eine große Menge an Broadcast-, Multicast- oder unbekannten Unicast-Paketen erzeugt. Ohne einen Schutz würde dieser Sturm die gesamte Bandbreite auffressen und das Netz für alle anderen Geräte unbrauchbar machen. Storm Control begrenzt den Anteil solcher Pakete am gesamten Datenverkehr eines Ports.

Sobald der definierte Schwellenwert überschritten wird, schaltet der Switch den Port ab. So wird verhindert, dass ein einzelnes Problem das gesamte Netz in Mitleidenschaft zieht.

```
interface GigabitEthernet0/5
 storm-control broadcast level 20.00
 storm-control action shutdown
```

Auf diese Weise lässt sich mit dem `Storm_Control_Audit`-Testfall in DiagNet automatisch prüfen, ob die Grenzwerte auf allen Access-Ports korrekt gesetzt sind und die eingestellte Aktion im Ernstfall greift.

#pagebreak()

=== Einseitige Fehler mit UDLD erkennen

Bei Verbindungen über Glasfaser kann es passieren, dass nur eine der beiden Fasern beschädigt ist. Da Spanning Tree dies oft nicht bemerkt, wird #htl3r.full[udld] im aggressiven Modus auf den Uplinks eingesetzt. Wenn der Switch keine Antwort vom Nachbarn erhält, geht er von einem Defekt aus und deaktiviert den Port.

```
udld enable

interface GigabitEthernet0/24
 udld port aggressive
```

=== Absicherung der Management-Zugänge

Der Zugriff auf die Switches für die Verwaltung wurde ebenfalls abgesichert. Für den administrativen Zugriff stehen #htl3r.short[ssh] und Telnet zur Verfügung, wobei Web-Server-Dienste deaktiviert wurden. DiagNet unterstützt beide Protokolle, um eine flexible Anbindung an unterschiedliche Geräte zu ermöglichen.

```
no ip http server
no ip http secure-server
```

Für die Speicherung der Passwörter wird der sichere `scrypt`-Algorithmus verwendet. Als Protokoll für den Austausch von Infos zwischen Nachbargeräten wird der offene Standard #htl3r.full[lldp] bevorzugt.

```
username dnadmin privilege 15 algorithm-type scrypt secret <Passwort>
```
