#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Danijel Stamenkovic")
== Switching-Tests <switching_tests>

Die automatische Prüfung einer Netzwerkinfrastruktur hängt stark von der Qualität der eingesetzten Testfälle ab. Für die Switching-Ebene wurden im Rahmen von DiagNet insgesamt 18 Testfälle entwickelt, welche die wichtigsten Sicherheitsmerkmale auf Layer 2 abdecken. Jeder Testfall wurde als eigene Python-Klasse umgesetzt, welche von einer gemeinsamen Basisklasse erbt.

=== Aufbau der Testfälle und Basisklasse

Jeder Switching-Testfall erbt von `DiagNetTest` (siehe @test_engine_arch) und implementiert die Prüflogik in Methoden mit dem Präfix `test_`. Zusätzlich steht die Methode `_setup()` zur Verfügung, die genau einmal vor allen Testmethoden ausgeführt wird. Man nutzt sie, um die SSH-Verbindung zum Switch aufzubauen und alle benötigten Geräteantworten zwischenzuspeichern, sodass alle Teilprüfungen auf demselben Konfigurationsstand arbeiten:

```python
from networktests.testcases.base import DiagNetTest, depends_on

class EtherChannel_Audit(DiagNetTest):
    _params = [...]      # Definition der Parameter

    def _setup(self):    # Wird vor den Tests ausgeführt
        self.genie_dev = self.device.get_genie_device_object(log_stdout=False)
        self._ec_summary = self.genie_dev.execute("show etherchannel summary")

    def test_member_port_bundling(self):  # Eine einzelne Testmethode
        ...
```

#pagebreak()

=== Alle Switching-Testfälle im Überblick

In der folgenden Tabelle sind alle 18 entwickelten Testfälle für den Switching-Bereich aufgelistet. Man kann diese über die Weboberfläche konfigurieren und einem bestimmten Gerät zuweisen.

#figure(
  table(
    columns: (auto, 1fr),
    inset: 8pt,
    align: (left, left),
    table.header([*Testfall*], [*Was wird geprüft?*]),
    [`AAA_Radius_Configuration`],
    [RADIUS-Anbindung und die Methoden für den Login],

    [`Access_Port_Compliance`],
    [VLAN-Zuweisung und der Modus der Endgeräte-Ports],

    [`Device_Identity_Crypto_Audit`],
    [Hostname, Domain und die Stärke der SSH-Verschlüsselung],

    [`DHCP_Snooping_Security_Audit`],
    [Aktivierung von DHCP Snooping und die vertrauenswürdigen Ports],

    [`Dynamic_ARP_Inspection_Audit`],
    [Aktivierung von DAI und die korrekten Einstellungen je VLAN],

    [`Errdisable_Recovery_Audit`],
    [Gründe für die Wiederherstellung und die Zeitintervalle],

    [`EtherChannel_Audit`],
    [Zustand des Port-Channels und die aktiven Leitungen],

    [`LLDP_CDP_Infrastructure_Audit`],
    [Zustand von LLDP und CDP sowie die Liste der Nachbarn],

    [`Local_Account_Security`],
    [Lokale Nutzer für den Notfall und deren Verschlüsselung],

    [`MAC_Address_Table_Stability`],
    [Größe der MAC-Tabelle und Stabilität der Einträge],

    [`Management_Plane_Security`],
    [Deaktivierung von HTTP, verfügbare Protokolle sowie SSH-Version],

    [`Port_Security_Audit`],
    [MAC-Limit, Sticky-Funktion und die Reaktion bei Verstößen],

    [`Rapid_PVST_Root_Audit`], [Rolle der Root-Bridge für jedes einzelne VLAN],

    [`Storm_Control_Audit`],
    [Grenzwerte für Broadcasts und die eingestellte Aktion],

    [`SVI_Management_Hardening`],
    [IP-Adresse und Erreichbarkeit der Management-Schnittstelle],

    [`Switchport_Trunk_Audit`], [Modus der Trunk-Ports und das Native VLAN 999],

    [`UDLD_Fiber_Integrity_Audit`],
    [Aktivierung von UDLD im aggressiven Modus auf den Uplinks],

    [`VTP_DTP_Security_Audit`],
    [Modus von VTP und Deaktivierung von DTP auf allen Ports],
  ),
  caption: [Die 18 Switching-Testfälle von DiagNet.],
) <tab-switching-testcases>

=== Details zu ausgewählten Tests

Man kann sich vier dieser Testfälle genauer ansehen, um die Logik hinter der Applikation zu verstehen.

==== EtherChannel_Audit
Dieser Test prüft den Zustand eines gebündelten Kanals in mehreren Schritten. Da die Abfrage der einzelnen Leitungen nur Sinn ergibt, wenn der Kanal selbst aktiv ist, wurde hier eine Abhängigkeit zwischen den Methoden eingebaut. Man nutzt reguläre Ausdrücke, um aus der Textausgabe des Switches die wichtigen Status-Flags wie zum Beispiel `(P)` für einen aktiven Port zu extrahieren.

==== Port_Security_Audit
Hier wird das Prinzip des Zwischenspeicherns deutlich. In der Einrichtung des Tests wird der Befehl für die Schnittstelle einmal ausgeführt und das Ergebnis gespeichert. Alle weiteren Teilprüfungen wie das MAC-Limit oder die Reaktion bei Verstößen greifen nur auf diesen gespeicherten Text zu. Dies sorgt für eine schnelle Ausführung der Tests.

==== Rapid_PVST_Root_Audit
Dieser Test prüft erst den Modus des Spanning Tree und danach die Rolle des Switches für ein bestimmtes VLAN. Durch einen Parameter kann man festlegen, ob der Switch die Root-Bridge sein soll oder nicht. So lässt sich derselbe Testfall für den Distribution-Switch und die Access-Switches verwenden.

==== VTP_DTP_Security_Audit
Bei diesem Test wird eine Besonderheit genutzt, denn anstatt nur einen Port zu prüfen, scannt man alle Schnittstellen des Switches auf einmal. Man sucht in der Ausgabe des Befehls gezielt nach Ports, bei denen die Trunk-Aushandlung noch aktiv ist. Dies ist wichtig, da bereits ein einziger falsch konfigurierter Port ein Sicherheitsrisiko darstellt.

=== Ausführung der Tests

Wenn ein Testlauf gestartet wird, arbeitet DiagNet alle Testfälle nacheinander ab. Die Verbindung wird über die Bibliothek Genie aus dem Cisco pyATS-Ökosystem aufgebaut, welche eine stabile Kommunikation über SSH ermöglicht. Während der Prüfung wird der Status laufend in die Datenbank geschrieben, damit man den Fortschritt in Echtzeit auf dem Dashboard verfolgen kann. Wenn ein Gerät nicht erreichbar ist, wird dies als Fehler markiert und man macht mit dem nächsten Testfall weiter.

=== Gefundene Abweichungen im Labor

Durch den Einsatz der automatisierten Tests konnten bereits während der Entwicklung einige Fehler in der Konfiguration der Switches gefunden werden. Man stellte zum Beispiel fest, dass an manchen Ports der falsche Modus für die Port-Security eingestellt war. Auch fehlende Einstellungen für die automatische Wiederherstellung von abgeschalteten Ports wurden durch die Tests schnell entdeckt. Ohne DiagNet wären diese kleinen Abweichungen vom Sicherheitskonzept wahrscheinlich über einen langen Zeitraum unbemerkt geblieben.
