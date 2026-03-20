#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Danijel Stamenkovic")

== Switching-Tests <switching_tests>

Die automatische Prüfung einer Netzwerkinfrastruktur hängt stark von der Qualität der eingesetzten Testfälle ab. Für die Switching-Ebene wurden im Rahmen von DiagNet insgesamt 18 Testfälle entwickelt, welche die wichtigsten Sicherheitsmerkmale auf Layer 2 abdecken. Damit wurde die Anforderung der Diplomarbeit, welche mindestens 15 Testfälle für diesen Bereich vorsieht, bewusst übertroffen, um eine lückenlose Abdeckung zu erreichen. Jeder Testfall wurde als eigene Python-Klasse umgesetzt, welche von einer gemeinsamen Basisklasse erbt.

=== Aufbau der Testfälle und Basisklasse

Die Grundlage für jeden Testfall bildet die Klasse `DiagNetTest`. Diese Klasse kümmert sich um die Auflösung von Parametern, die Verwaltung von Abhängigkeiten und die Behandlung von Fehlern. Beim Erstellen eines neuen Testfalls müssen lediglich die spezifischen Methoden für die Prüfung definiert werden, während das restliche Grundgerüst von der Basisklasse bereitgestellt wird.

#htl3r.code(
  caption: [Aufbau eines Switching-Testfalls mit Basisklasse und `_setup()`-Methode],
  description: `networktests/testcases/etherchannel_audit.py`,
)[
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
]

Die Methode `_setup()` ist dabei von großer Bedeutung. Sie wird genau einmal vor allen anderen Methoden in der Klasse ausgeführt. Sie wird genutzt, um die Verbindung zum Switch aufzubauen und alle benötigten Ausgaben der Befehle zwischenzuspeichern. Durch dieses Vorgehen werden unnötige Verbindungen vermieden zum Gerät und stellt sicher, dass alle Teilprüfungen innerhalb einer Klasse auf dem exakt gleichen Stand der Konfiguration arbeiten.

Über den Dekorator `@depends_on` lassen sich Abhängigkeiten zwischen den Methoden festlegen. Wenn eine grundlegende Prüfung fehlschlägt, werden alle darauf aufbauenden Methoden automatisch übersprungen und als `SKIPPED` markiert. Dies ist sinnvoll, da ein Test ohne erfüllte Voraussetzungen keine verlässlichen Aussagen liefern kann und nicht mit einem echten Fehler verwechselt werden soll.

=== Parameter und Validierung der Eingaben

Jeder Testfall legt seine benötigten Parameter über die Liste `_params` fest. Dort werden der Name, der Text für die Anzeige sowie der Typ des Parameters definiert. Auf Basis dieser Informationen wird in der Weboberfläche von DiagNet automatisch das passende Eingabefeld erstellt. Es stehen verschiedene Typen zur Verfügung.

#figure(
  table(
    columns: (auto, 1fr),
    inset: 8pt,
    align: (left, left),
    table.header([*Typ*], [*Verhalten und Nutzen*]),
    [`device`], [Auswahl eines Geräts aus der Datenbank über ein Dropdown-Menü],

    [`cisco-interface`],
    [Eingabefeld für Schnittstellen wie zum Beispiel Gi0/1 oder GigabitEthernet0/1],

    [`positive-number`],
    [Feld für positive ganze Zahlen inklusive einer Prüfung der Eingabe],

    [`choice`], [Dropdown-Menü mit fest vorgegebenen Antwortmöglichkeiten],

    [`ipv4`], [Feld für IP-Adressen mit einer automatischen Formatprüfung],

    [`text`],
    [Einfaches Textfeld für beliebige Eingaben wie Namen oder Domains],
  ),
  caption: [Die verschiedenen Parametertypen in DiagNet.],
) <tab-param-types>

Der Typ `cisco-interface` ist in der Praxis sehr wichtig, da Cisco-Geräte die Namen von Schnittstellen in verschiedenen Befehlen unterschiedlich ausgeben. Ob nun Gi0/1 oder der volle Name eingegeben wird, spielt für DiagNet keine Rolle, da die Eingabe intern auf ein einheitliches Format gebracht wird.

=== Alle Switching-Testfälle im Überblick

In der folgenden Tabelle sind alle 18 entwickelten Testfälle für den Switching-Bereich aufgelistet. Diese lassen sich über die Weboberfläche konfigurieren und einem bestimmten Gerät zuweisen.

#figure(
  table(
    columns: (auto, 1fr, auto),
    inset: 8pt,
    align: (left, left, center),
    table.header([*Testfall*], [*Was wird geprüft?*], [*Zielgerät*]),
    [`AAA_Radius_Configuration`],
    [RADIUS-Anbindung und die Methoden für den Login],
    [Alle Switches],

    [`Access_Port_Compliance`],
    [VLAN-Zuweisung und der Modus der Endgeräte-Ports],
    [ASW-1, ASW-2],

    [`Device_Identity_Crypto_Audit`],
    [Hostname, Domain und die Stärke der SSH-Verschlüsselung],
    [Alle Switches],

    [`DHCP_Snooping_Security_Audit`],
    [Aktivierung von DHCP Snooping und die vertrauenswürdigen Ports],
    [ASW-1, ASW-2],

    [`Dynamic_ARP_Inspection_Audit`],
    [Aktivierung von DAI und die korrekten Einstellungen je VLAN],
    [ASW-1, ASW-2],

    [`Errdisable_Recovery_Audit`],
    [Gründe für die Wiederherstellung und die Zeitintervalle],
    [Alle Switches],

    [`EtherChannel_Audit`],
    [Zustand des Port-Channels und die aktiven Leitungen],
    [DSW, ASW-1/2],

    [`LLDP_CDP_Infrastructure_Audit`],
    [Zustand von LLDP und CDP sowie die Liste der Nachbarn],
    [Alle Switches],

    [`Local_Account_Security`],
    [Lokale Nutzer für den Notfall und deren Verschlüsselung],
    [Alle Switches],

    [`MAC_Address_Table_Stability`],
    [Größe der MAC-Tabelle und Stabilität der Einträge],
    [ASW-1, ASW-2],

    [`Management_Plane_Security`],
    [Deaktivierung von HTTP, verfügbare Protokolle sowie SSH-Version],
    [Alle Switches],

    [`Port_Security_Audit`],
    [MAC-Limit, Sticky-Funktion und die Reaktion bei Verstößen],
    [ASW-1, ASW-2],

    [`Rapid_PVST_Root_Audit`],
    [Rolle der Root-Bridge für jedes einzelne VLAN],
    [DSW, ASW-1/2],

    [`Storm_Control_Audit`],
    [Grenzwerte für Broadcasts und die eingestellte Aktion],
    [ASW-1, ASW-2],

    [`SVI_Management_Hardening`],
    [IP-Adresse und Erreichbarkeit der Management-Schnittstelle],
    [DSW],

    [`Switchport_Trunk_Audit`],
    [Modus der Trunk-Ports und das Native VLAN 999],
    [DSW, ASW-1/2],

    [`UDLD_Fiber_Integrity_Audit`],
    [Aktivierung von UDLD im aggressiven Modus auf den Uplinks],
    [DSW, ASW-1/2],

    [`VTP_DTP_Security_Audit`],
    [Modus von VTP und Deaktivierung von DTP auf allen Ports],
    [DSW, ASW-1/2],
  ),
  caption: [Die 18 Switching-Testfälle von DiagNet.],
) <tab-switching-testcases>
#pagebreak()
=== Details zu ausgewählten Tests

Vier dieser Testfälle werden im Folgenden genauer betrachtet, um die Logik hinter der Applikation zu verstehen.

==== EtherChannel_Audit
Dieser Testfall prüft den Zustand eines gebündelten Kanals in mehreren Schritten. Als Grundlage dient die Ausgabe des Befehls `show etherchannel summary`, welcher eine kompakte Übersicht aller konfigurierten Port-Channel-Interfaces liefert. Zunächst wird geprüft, ob das angegebene Port-Channel-Interface überhaupt aktiv ist. Dazu wird in der Ausgabe nach dem Flag `(U)`, das einen betriebsbereiten Kanal kennzeichnet. Erst wenn diese Prüfung erfolgreich ist, werden über den Dekorator `@depends_on` die abhängigen Methoden ausgeführt, welche die einzelnen Mitgliedsports auf das Flag `(P)` prüfen. Dieses Flag zeigt an, dass ein Port aktiv im Bündel eingebunden ist. Ports mit dem Flag `(D)` oder `(s)` wären hingegen ausgefallen beziehungsweise ausgesetzt und würden den Test fehlschlagen lassen. Durch diese Struktur werden irreführende Fehlerausgaben vermieden für Ports, wenn der Kanal selbst gar nicht aktiv ist.

==== Port_Security_Audit
Hier wird das Prinzip des einmaligen Abrufens und mehrfachen Auswertens besonders deutlich. In der `_setup()`-Methode wird der Befehl `show port-security interface <interface>` genau einmal über SSH ausgeführt und die zurückgegebene Textausgabe im Objekt gespeichert. Die nachfolgenden Prüfmethoden arbeiten ausschließlich auf diesem gespeicherten Text, ohne erneut eine Verbindung zum Gerät aufzubauen. Konkret wird überprüft, ob die maximale Anzahl zulässiger MAC-Adressen korrekt gesetzt ist, ob die Verletzungsreaktion auf `shutdown` steht und ob das Sticky-Learning aktiv ist. Gerade der Violation-Mode ist sicherheitstechnisch entscheidend: Nur mit `shutdown` wird ein Port bei einem unbekannten Gerät sofort deaktiviert, während `restrict` oder `protect` lediglich den Datenverkehr einschränken, ohne den Vorfall aktiv zu unterbinden.
#pagebreak()
==== Rapid_PVST_Root_Audit
In diesem Test sind zwei aufeinander aufbauende Prüfungen kombiniert. Zuerst wird über `show spanning-tree summary` sichergestellt, dass der Switch tatsächlich im Rapid-PVST+-Modus betrieben wird, da nur dieser Modus eine VLAN-spezifische Root-Bridge-Auswahl unterstützt. Danach wird mit `show spanning-tree vlan <vlan-id>` die Rolle des Switches für das angegebene VLAN geprüft. Über einen `choice`-Parameter lässt sich dabei konfigurieren, ob der Switch die Root-Bridge sein soll oder explizit nicht. So kann derselbe Testfall sowohl für den DSW, der die Root-Bridge halten soll, als auch für ASW-1 und ASW-2 eingesetzt werden, die das niemals sein dürfen. Eine falsch gewählte Root-Bridge würde den Datenverkehr über suboptimale Pfade leiten und die Stabilität des Spanning Trees gefährden.

==== VTP_DTP_Security_Audit
Bei diesem Beispiel zeigt sich eine Besonderheit. Anstatt nur eine einzelne Schnittstelle zu prüfen, werden alle Ports des Switches gleichzeitig untersucht. Über `show interfaces trunk` wird die gesamte Liste der Schnittstellen abgerufen, und mithilfe eines regulären Ausdrucks wird gezielt nach Ports gesucht, auf denen DTP noch aktiv aushandelt. Jeder solche Port stellt ein potenzielles Angriffsziel dar, da ein Angreifer mit einem rogue Switch einen Trunk aufbauen und dadurch Zugriff auf alle VLANs erlangen könnte. Zusätzlich wird der VTP-Modus des jeweiligen Geräts geprüft: Der DSW soll als VTP-Server konfiguriert sein, während ASW-1 und ASW-2 im Client-Modus betrieben werden müssen. Eine falsche Rollenzuweisung würde bedeuten, dass ein Access-Switch eigenständig VLAN-Änderungen in die Domain propagieren könnte, was unerwünscht ist.

=== Ausführung der Tests

Wenn ein Testlauf gestartet wird, arbeitet DiagNet alle Testfälle nacheinander ab. Die Verbindung wird über die Bibliothek Genie aus dem Cisco pyATS-Ökosystem aufgebaut, welche eine stabile Kommunikation über SSH oder Telnet ermöglicht. Während der Prüfung wird der Status laufend in die Datenbank geschrieben, damit der Fortschritt in Echtzeit auf dem Dashboard verfolgt werden kann. Wenn ein Gerät nicht erreichbar ist, wird dies als Fehler markiert und es wird mit dem nächsten Testfall fortgefahren.
#pagebreak()
=== Gefundene Abweichungen im Labor

Durch den Einsatz der automatisierten Tests konnten bereits während der Entwicklung einige Fehler in der Konfiguration der Switches gefunden werden. So wurde zum Beispiel festgestellt, dass an manchen Ports der falsche Modus für die Port-Security eingestellt war. Auch fehlende Einstellungen für die automatische Wiederherstellung von abgeschalteten Ports wurden durch die Tests schnell entdeckt. Ohne DiagNet wären diese kleinen Abweichungen vom Sicherheitskonzept wahrscheinlich über einen langen Zeitraum unbemerkt geblieben.
