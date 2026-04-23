#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Danijel Stamenkovic")

== Switching & Layer 2 <switching_infra>

Bei der Planung der Layer-2-Ebene für die DiagNet-Infrastruktur wurde sich an Standards orientiert, wie sie auch in modernen Firmennetzen zum Einsatz kommen. Es wurde kein rein theoretisches Modell entworfen, sondern es wurden Funktionen gewählt, die in der täglichen Praxis eine hohe Relevanz besitzen und sich automatisiert prüfen lassen. Diese Konfiguration wurde identisch auf den physischen Switches im Labor sowie in der GNS3-Simulationsumgebung umgesetzt, damit eine einheitliche Basis für alle Tests vorhanden ist. Die verschiedenen Funktionen bauen logisch aufeinander auf, was bei der Fehlersuche immer im Hinterkopf behalten werden sollte.

=== Spanning Tree mit Rapid PVST+

In jedem geswitchten Netzwerk mit redundanten Wegen wird ein Protokoll benötigt, das Schleifen verhindert. Ohne einen solchen Schutz würden Broadcast-Stürme das Netz innerhalb kürzester Zeit lahmlegen. Hierfür wird das #htl3r.full[stp] eingesetzt, welches redundante Verbindungen logisch sperrt und sie erst dann freischaltet, wenn der primäre Pfad ausfällt.

In der DiagNet-Infrastruktur wird die Variante #htl3r.full[pvst] genutzt @cisco-stp-pvst. Bei diesem Standard lässt Cisco für jedes VLAN eine eigene Instanz des Spanning Tree laufen, wodurch sich der Datenverkehr über verschiedene Uplinks verteilen lässt. Der Distribution-Switch wurde dabei fest als Root-Bridge definiert, da dieser den zentralen Punkt im Netzwerk bildet. Dies wurde über die Bridge-Priority gelöst, indem der Befehl `root primary` verwendet wurde, was dem Switch eine Priorität von 24576 zuweist, sofern keine Bridge mit niedrigerer Priorität im Netz vorhanden ist.

#htl3r.code(
  caption: [Aktivierung von Rapid PVST+ und Setzen der Root-Bridge-Priorität],
  description: `switch-config`,
)[
  ```
  spanning-tree mode rapid-pvst
  spanning-tree vlan 1-4094 root primary
  ```
]
#pagebreak()
An den Ports, an denen Endgeräte angeschlossen sind, wurde die Funktion _PortFast_ aktiviert. Normalerweise müsste bis zu 30 Sekunden gewartet werden, bis ein Port Daten senden darf, was durch PortFast umgangen wird. Damit jedoch kein fremder Switch an so einen Port gesteckt werden kann, ist gleichzeitig der _#htl3r.full[bpdu] Guard_ aktiv. Sobald ein BPDU-Paket an einem solchen Port empfangen wird, schaltet der Switch diesen sofort ab.

#htl3r.code(
  caption: [Konfiguration von PortFast und BPDU Guard auf Access-Ports],
  description: `switch-config`,
)[
  ```
  interface range GigabitEthernet0/3 - 24
   spanning-tree portfast
   spanning-tree bpduguard enable
  ```
]

=== Höhere Bandbreite durch EtherChannel

Einzelne Gigabit-Verbindungen zwischen den Switches könnten bei viel Datenverkehr schnell zum Engpass werden. Deshalb wird #htl3r.full[lacp] genutzt, um mehrere physische Leitungen zu einem logischen Kanal zu bündeln. Dies bringt nicht nur mehr Geschwindigkeit, sondern sorgt auch für eine höhere Ausfallsicherheit, da beim Riss eines Kabels die anderen Leitungen den Verkehr sofort übernehmen.

Die Konfiguration wurde mit dem Parameter `mode active` durchgeführt. Das bedeutet, dass der Switch von sich aus versucht, den Kanal mit der Gegenseite auszuhandeln. So wird sichergestellt, dass der EtherChannel stabil aufgebaut wird, egal welches Gerät zuerst eingeschaltet wird.

#htl3r.code(
  caption: [EtherChannel-Konfiguration mit LACP im aktiven Modus],
  description: `switch-config`,
)[
  ```
  interface range GigabitEthernet0/1 - 2
   channel-group 1 mode active

  interface Port-channel1
   switchport mode trunk
   switchport trunk native vlan 999
  ```
]

Damit die Datenpakete gleichmäßig auf die verfügbaren Leitungen verteilt werden, kommt der `src-dst-mac`-Algorithmus zum Einsatz. Der Switch entscheidet anhand der MAC-Adressen von Sender und Empfänger, über welches Kabel die Daten geschickt werden, damit die Reihenfolge der Pakete innerhalb einer Verbindung erhalten bleibt.

=== VLAN-Verwaltung mit VTP und DTP

Damit nicht auf jedem einzelnen Switch manuell alle VLANs angelegt werden müssen, wird das #htl3r.full[vtp] in der Version 2 verwendet. Die Domain trägt den Namen `DIAGNET`. Der Distribution-Switch arbeitet hierbei als Server, während die Access-Switches als Clients konfiguriert wurden. So werden Änderungen an der VLAN-Struktur automatisch im ganzen Netz verteilt, was Zeit spart und Tippfehler verhindert.

Beim Trunking wurde das Protokoll #htl3r.full[dtp] auf allen Leitungen komplett abgeschaltet. Es soll verhindert werden, dass ein Port von sich aus entscheidet, ob er zu einem Trunk wird oder nicht. Mit dem Befehl `switchport nonegotiate` wird dieser Zustand festgeschrieben. Dies ist eine wichtige Maßnahme gegen Angriffe, bei denen jemand versucht, unerlaubt Zugriff auf andere VLANs zu erhalten.

#htl3r.code(
  caption: [Trunk-Konfiguration mit deaktiviertem DTP und erlaubten VLANs],
  description: `switch-config`,
)[
  ```
  interface GigabitEthernet0/24
   switchport mode trunk
   switchport nonegotiate
   switchport trunk native vlan 999
   switchport trunk allowed vlan 10,20,99,999
  ```
]
#pagebreak()
=== DHCP Snooping als Schutzmaßnahme

Das Protokoll #htl3r.full[dhcp] ist oft ein Ziel für Angriffe. Ein Angreifer könnte einen eigenen Server ins Netz hängen, um den Datenverkehr über sich umzuleiten. Um das zu verhindern, wird DHCP Snooping eingesetzt. Dabei wird festgelegt, welche Ports als vertrauenswürdig gelten und welche nicht.

Nur die Uplinks zum Distribution-Switch wurden als vertrauenswürdig markiert. Wenn an einem normalen Port für Endgeräte eine Antwort von einem DHCP-Server ankommt, wird diese vom Switch sofort verworfen @cisco-layer2-security.

#htl3r.code(
  caption: [Aktivierung von DHCP Snooping mit vertrauenswürdigem Uplink-Port],
  description: `switch-config`,
)[
  ```
  ip dhcp snooping
  ip dhcp snooping vlan 10,20,99

  interface GigabitEthernet0/24
   ip dhcp snooping trust
  ```
]

Durch das Snooping baut der Switch zudem eine Tabelle auf, in der die Zuweisungen von #htl3r.short[ip]-Adressen zu MAC-Adressen gespeichert sind. Diese Informationen sind die Grundlage für weitere Sicherheitsprüfungen im Netzwerk.
#pagebreak()
=== Überprüfung mit Dynamic ARP Inspection

Das Protokoll #htl3r.full[arp] hat von Haus aus keine Sicherheitsfunktionen, was Angriffe wie das ARP-Spoofing ermöglicht. Hierbei werden gefälschte Nachrichten verschickt, um Daten abzufangen. Zur Abwehr wird #htl3r.short[dai] eingesetzt, welche jedes eingehende Paket gegen die Tabelle aus dem DHCP Snooping prüft.

Passt die Kombination aus #htl3r.short[ip] und MAC nicht zu den gespeicherten Daten, wird das Paket gelöscht. WSie beim Snooping werden auch hier nur die Uplink-Ports als vertrauenswürdig eingestuft.

#htl3r.code(
  caption: [Aktivierung von Dynamic ARP Inspection für die VLANs 10,20 und 99 mit vertrauenswürdigem Port],
  description: `switch-config`,
)[
  ```
  ip arp inspection vlan 10,20,99

  interface GigabitEthernet0/24
   ip arp inspection trust
  ```
]

=== Sicherheit am Port durch Port Security

Auf jedem Port für Endgeräte wurde Port Security aktiviert. Dabei wird genau eine MAC-Adresse pro Port erlaubt, welche der Switch beim ersten Kontakt automatisch lernt und in der Konfiguration speichert.

#htl3r.code(
  caption: [Port Security mit Sticky MAC-Adresse und Shutdown bei Verstoß],
  description: `switch-config`,
)[
  ```
  switchport port-security
  switchport port-security maximum 1
  switchport port-security violation shutdown
  switchport port-security mac-address sticky
  ```
]

Falls ein Verstoß erkannt wird, schaltet der Switch den Port sofort ab. Damit bei Fehlern nicht jedes Mal manuell eingegriffen werden muss, wurde eine automatische Wiederherstellung nach 300 Sekunden konfiguriert.

=== Schutz vor Broadcast-Überflutung mit Storm Control

In einem geswitchten Netz kann es passieren, dass ein einzelnes Gerät oder eine fehlerhafte Konfiguration plötzlich eine große Menge an Broadcast-, Multicast- oder unbekannten Unicast-Paketen erzeugt. Ohne einen Schutz würde dieser Sturm die gesamte Bandbreite auffressen und das Netz für alle anderen Geräte unbrauchbar machen. Storm Control begrenzt den Anteil solcher Pakete am gesamten Datenverkehr eines Ports.

Sobald der definierte Schwellenwert überschritten wird, schaltet der Switch den Port ab. So wird verhindert, dass ein einzelnes Problem das gesamte Netz in Mitleidenschaft zieht.

#htl3r.code(
  caption: [Storm Control mit 20%-Grenzwert für Broadcasts und Shutdown-Aktion],
  description: `switch-config`,
)[
  ```
  interface GigabitEthernet0/5
   storm-control broadcast level 20.00
   storm-control action shutdown
  ```
]

Auf diese Weise lässt sich mit dem `Storm_Control_Audit`-Testfall in DiagNet automatisch prüfen, ob die Grenzwerte auf allen Access-Ports korrekt gesetzt sind und die eingestellte Aktion im Ernstfall greift.

=== Einseitige Fehler mit UDLD erkennen

Bei Verbindungen über Glasfaser kann es passieren, dass nur eine der beiden Fasern beschädigt ist. Da Spanning Tree dies oft nicht bemerkt, wird #htl3r.full[udld] im aggressiven Modus auf den Uplinks eingesetzt. Wenn der Switch keine Antwort vom Nachbarn erhält, geht er von einem Defekt aus und deaktiviert den Port.

#htl3r.code(
  caption: [Aktivierung von UDLD im aggressiven Modus auf dem Uplink-Port],
  description: `switch-config`,
)[
  ```
  udld enable

  interface GigabitEthernet0/24
   udld port aggressive
  ```
]

=== Absicherung der Management-Zugänge

Der Zugriff auf die Switches für die Verwaltung wurde ebenfalls abgesichert. Für den administrativen Zugriff stehen #htl3r.short[ssh] und Telnet zur Verfügung, wobei Web-Server-Dienste deaktiviert wurden. DiagNet unterstützt beide Protokolle, um eine flexible Anbindung an unterschiedliche Geräte zu ermöglichen.

#htl3r.code(
  caption: [Deaktivierung der HTTP- und HTTPS-Verwaltungsschnittstelle],
  description: `switch-config`,
)[
  ```
  no ip http server
  no ip http secure-server
  ```
]

Für die Speicherung der Passwörter wird der sichere `scrypt`-Algorithmus verwendet. Als Protokoll für den Austausch von Informationen zwischen Nachbargeräten wird der offene Standard #htl3r.full[lldp] bevorzugt.

#htl3r.code(
  caption: [Lokaler Administrator-Account mit scrypt-Passwortverschlüsselung],
  description: `switch-config`,
)[
  ```
  username dnadmin privilege 15 algorithm-type scrypt secret <Passwort>
  ```
]
