#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Benedikt Theuretzbachner")
== Absicherung des Netzwerkzugriffs
In klassischen Netzwerkinfrastrukturen erfolgt der Zugriff auf das Netzwerk häufig ausschließlich über die physische Verbindung zu einem Switchport. Wird ein Gerät an einen aktiven Port angeschlossen, erhält es in vielen Fällen unmittelbar Zugang zum internen Netzwerk. Diese Vorgehensweise stellt ein erhebliches Sicherheitsrisiko dar, da nicht überprüft wird, ob es sich bei dem angeschlossenen Gerät um ein berechtigtes Endgerät handelt.

Ein ähnliches Problem besteht bei der administrativen Anmeldung auf Netzwerkkomponenten. Werden lokale Benutzerkonten auf Routern und Switches verwendet, müssen Zugangsdaten auf jedem Gerät einzeln verwaltet werden. Änderungen von Passwörtern oder Benutzerrechten müssen somit auf allen Geräten separat durchgeführt werden. Dies erhöht nicht nur den administrativen Aufwand, sondern erschwert auch die Nachvollziehbarkeit von Zugriffen.

Zur Verbesserung der Netzwerksicherheit wurde daher eine zentrale Lösung zur Absicherung des Netzwerkzugriffs implementiert. Ziel dieser Lösung ist es, sowohl den Zugriff von Administratoren auf Netzwerkgeräte als auch den Zugriff von Endgeräten auf das Netzwerk zu kontrollieren und zentral zu verwalten.

Die Umsetzung erfolgt mittels einer Network-Access-Control-Lösung auf Basis der Cisco Identity Services Engine (ISE). Dabei werden zwei zentrale Mechanismen eingesetzt:

- Authentifizierung von Administratoren auf Netzwerkgeräten über das RADIUS-Protokoll
- Authentifizierung von Endgeräten an Access-Switchports mittels IEEE 802.1X

Ein wesentliches Ziel dieser Architektur ist eine Single Source of Truth für Authentifizierungs- und Autorisierungsinformationen. Dabei werden Benutzerkonten, Geräteinformationen sowie Zugriffsrichtlinien nicht mehr lokal auf einzelnen Netzwerkgeräten gespeichert, sondern zentral durch die Cisco Identity Services Engine verwaltet. Änderungen an Zugriffsrechten oder Richtlinien müssen dadurch nur an einer Stelle vorgenommen werden und gelten unmittelbar für alle angebundenen Netzwerkkomponenten.

Die im Rahmen der Testumgebung implementierte Lösung verfolgt somit mehrere Ziele:

- Erhöhung der Netzwerksicherheit durch kontrollierten Netzwerkzugang
- Zentrale Authentifizierung von Administratoren auf Netzwerkgeräten
- Authentifizierung von Endgeräten über IEEE 802.1X
- Dynamische Zuweisung von VLANs auf Basis definierter Richtlinien
- Zentrale Verwaltung von Benutzern, Geräten und Zugriffspolicies im Sinne einer Single Source of Truth

Die folgenden Abschnitte erläutern zunächst die grundlegenden Konzepte von Network Access Control sowie die Funktionsweise der eingesetzten Technologien. Anschließend wird die konkrete Umsetzung der Authentifizierungsmechanismen in der aufgebauten Testumgebung beschrieben.

=== Network Access Control

Network Access Control (NAC) bezeichnet ein Sicherheitskonzept zur Kontrolle des Zugriffs auf ein Netzwerk. Ziel von NAC ist es, sicherzustellen, dass nur berechtigte Benutzer und Geräte Zugriff auf Netzwerkressourcen erhalten. Dabei wird der Netzwerkzugang nicht mehr ausschließlich durch die physische Verbindung zu einem Switchport bestimmt, sondern durch eine Authentifizierungs- und Autorisierungsprüfung.

In modernen Netzwerken ist NAC ein zentraler Bestandteil der Netzwerksicherheit. Ohne entsprechende Zugriffskontrollen könnte jedes beliebige Gerät, das physisch mit dem Netzwerk verbunden wird, potenziell Zugriff auf interne Ressourcen erhalten. NAC ermöglicht es, diesen Zugriff zu kontrollieren und auf Basis definierter Richtlinien zu steuern.

Ein typisches NAC-System besteht aus drei zentralen Komponenten:

- einem Endgerät, das Zugriff auf das Netzwerk anfordert
- einem Netzwerkgerät, das den Zugriff kontrolliert
- einem zentralen Authentifizierungsserver, der die Entscheidung über den Zugriff trifft

Das Endgerät wird als Supplicant bezeichnet. Dabei handelt es sich beispielsweise um einen Laptop oder einen Arbeitsplatzrechner, der mit dem Netzwerk verbunden wird. Das Netzwerkgerät, üblicherweise ein Access-Switch, übernimmt die Rolle des Authenticators. Dieser kontrolliert den Zugriff auf den jeweiligen Switchport und leitet Authentifizierungsanfragen an den zentralen Authentifizierungsserver weiter. Der Authentifizierungsserver überprüft die Identität des Benutzers oder Geräts und entscheidet auf Basis definierter Richtlinien, ob der Zugriff auf das Netzwerk erlaubt wird.

In der hier aufgebauten Testumgebung übernimmt die Cisco Identity Services Engine, auf welche später noch genauer eingegangen wird, die Rolle des zentralen Authentifizierungsservers. Die Access-Switches fungieren als Authenticator und setzen die vom Authentifizierungsserver getroffenen Entscheidungen auf den jeweiligen Switchports um.

#figure(
  image("../assets/nac_diagram.png", width: 100%),
  caption: [Abbildung der NAC Rollen],
)

Ein grundlegendes Konzept im Zusammenhang mit Network Access Control ist das sogenannte AAA-Modell. AAA steht für Authentication, Authorization und Accounting und beschreibt drei zentrale Funktionen der Zugriffskontrolle in Netzwerken.

- *Authentication* bezeichnet die Überprüfung der Identität eines Benutzers oder Geräts. Dabei wird festgestellt, ob die angegebene Identität gültig ist. Dies kann beispielsweise durch Benutzername und Passwort, Zertifikate oder andere Authentifizierungsmechanismen erfolgen.

- *Authorization* beschreibt die Entscheidung darüber, welche Rechte einem authentifizierten Benutzer oder Gerät im Netzwerk gewährt werden. Nach erfolgreicher Authentifizierung kann der Zugriff beispielsweise auf bestimmte Netzwerksegmente beschränkt oder ein bestimmtes VLAN zugewiesen werden.

- *Accounting* dient der Protokollierung und Nachvollziehbarkeit von Zugriffen. Dabei werden Authentifizierungsereignisse, Sitzungen sowie Netzwerkzugriffe protokolliert. Diese Informationen können für Sicherheitsanalysen, Fehlersuche oder Auditing-Zwecke verwendet werden.

Durch die Kombination von Network Access Control, dem AAA-Modell und einem zentralen Authentifizierungsserver wird eine kontrollierte und nachvollziehbare Zugriffskontrolle im Netzwerk ermöglicht. Zugriff auf das Netzwerk erhalten nur Benutzer und Geräte, die erfolgreich authentifiziert wurden und deren Zugriff durch definierte Richtlinien autorisiert wurde.

=== Cisco Identity Services Engine

Die Cisco Identity Services Engine (ISE) ist eine zentrale Plattform zur Umsetzung von Network Access Control in Cisco-Netzwerken. Sie übernimmt die Rolle des Authentifizierungs- und Autorisierungsservers und ermöglicht eine zentrale Verwaltung von Benutzern, Geräten sowie Zugriffsrichtlinien.

Neben der reinen Authentifizierung stellt die ISE auch umfangreiche Autorisierungsfunktionen bereit. Auf Basis definierter Richtlinien können unterschiedliche Zugriffsrechte vergeben werden. Authentifizierten Geräten können beispielsweise bestimmte VLANs zugewiesen oder Netzwerkzugriffe erlaubt beziehungsweise eingeschränkt werden.

Ein weiterer wichtiger Bestandteil der Plattform ist die Protokollierung von Authentifizierungsereignissen. Über die integrierten Monitoring- und Logging-Funktionen können Administratoren nachvollziehen, wann und von welchem Gerät aus eine Authentifizierung stattgefunden hat. Dadurch wird eine bessere Transparenz und Nachvollziehbarkeit von Netzwerkzugriffen ermöglicht.

In der aufgebauten Testumgebung wird die Cisco Identity Services Engine als zentrale Authentifizierungsinstanz für zwei unterschiedliche Anwendungsfälle eingesetzt. Einerseits erfolgt die administrative Anmeldung auf Netzwerkgeräten über das RADIUS-Protokoll. Andererseits wird die ISE für die Authentifizierung von Endgeräten über IEEE 802.1X verwendet. In beiden Fällen übernehmen die Netzwerkgeräte die Rolle eines RADIUS-Clients und leiten Authentifizierungsanfragen an die ISE weiter.

Die Cisco Identity Services Engine wird in der Testumgebung auf einem dedizierten Server betrieben. Als Hardwareplattform kommt ein Server des Typs Cisco UCS C220 M4 zum Einsatz. Dabei handelt es sich um einen Rack-Server aus der Cisco Unified Computing System (UCS) Produktfamilie, der für den Betrieb von Infrastrukturservices und Netzwerkmanagementsystemen ausgelegt ist.

Die grafische Administrationsoberfläche der Cisco Identity Services Engine ermöglicht die Konfiguration von Authentifizierungs- und Autorisierungsrichtlinien sowie die Verwaltung von Netzwerkgeräten, Benutzern und Gruppen. Zusätzlich können über die Monitoring-Funktionen aktuelle Authentifizierungsereignisse und Systemmeldungen eingesehen werden.

In folgender Abbildung ist das Dashboard der ISE zu sehen, welches unter anderem die Anzahl der Authentifizierungen und die Auslastung des Arbeitsspeichers zeigt:
#figure(
  image("../assets/ise-dashboard.png", width: 100%),
  caption: [Abbildung des ISE Dashboards],
)

Im weiteren Verlauf dieses Kapitels wird beschrieben, wie die Cisco Identity Services Engine konkret zur Absicherung administrativer Zugriffe auf Netzwerkgeräte sowie zur Authentifizierung von Endgeräten mittels IEEE 802.1X eingesetzt wurde.

=== Authentifizierung von Netzwerkadministratoren über RADIUS

In der Testumgebung wurde die administrative Anmeldung auf Netzwerkkomponenten an einen zentralen Punkt ausgelagert. Administratoren greifen typischerweise über Secure Shell (SSH) auf Router und Switches zu, um Konfigurationen vorzunehmen oder den Zustand der Geräte zu überprüfen.
Anstatt lokale Benutzerkonten auf jedem einzelnen Netzwerkgerät zu verwalten, werden Authentifizierungsanfragen an einen RADIUS-Server weitergeleitet. In der aufgebauten Infrastruktur übernimmt die Cisco Identity Services Engine diese Rolle. Netzwerkgeräte fungieren dabei als RADIUS-Clients und übermitteln Anmeldeversuche an die ISE, welche die Authentifizierung sowie die zugehörige Autorisierung gemäß den definierten Poilicies durchführt.

Durch diese zentrale Authentifizierung können Benutzerkonten und Zugriffsrechte an einer Stelle verwaltet werden. Änderungen an Benutzerkonten müssen nicht mehr auf jedem Gerät einzeln vorgenommen werden, sondern werden unmittelbar für alle angebundenen Netzwerkgeräte wirksam. Zusätzlich ermöglicht dieser Authentifizierungsinstanz eine Protokollierung administrativer Zugriffe, welche in der folgenden Abbildung zu sehen ist:

Ein Zentraler Vorteil dieser Architektur ist, dass Logs einheitlich protokolliert und an einem Punkt ersichtlich sind. In der folgenden Abbildung sind zwei Anmeldeversuche zu erkennen. Beide wurden an dem selben Netzwerkgerät durchgeführt, jedoch ist der zweite fehlgeschlagen, da die Verwendete Richtlinie nur Benutzer einer bestimmten Gruppe Authentifiziert:

#figure(
  image("../assets/ise-logs.png", width: 100%),
  caption: [ISE Live Logs],
)

Damit Netzwerkgeräte Authentifizierungsanfragen an die Cisco Identity Services Engine weiterleiten können, müssen sie als RADIUS-Clients konfiguriert werden. Dazu wird auf dem jeweiligen Gerät der RADIUS-Server definiert und anschließend in die Authentifizierung der Managementzugänge eingebunden.

In folgendem Beispiel wird der RADIUS Server auf der Firewall ZBFW-1 definiert:
#pagebreak()

#htl3r.code(
  caption: [Auszug aus der Firewall Konfiguration],
  description: `Cisco IOS Script`,
)[
  ```cisco
  radius server ISE
    address ipv4 10.0.99.10 auth-port 1812 acct-port 1813
    key <hier wurde das Passwort eingefügt>
  ```
]

Die verwendeted Ports sowie das Passwort wurden im vorhinein auf der ISE festgelegt.

In dieser Konfiguration werden Anmeldeversuche zunächst an den zentralen RADIUS-Server weitergeleitet. Ist dieser nicht erreichbar, kann optional ein lokaler Benutzer als Fallback verwendet werden. Auf diese Weise wird eine zentrale Verwaltung administrativer Zugriffe ermöglicht, ohne die Erreichbarkeit der Geräte im Fehlerfall zu gefährden.

=== Authentifizierung von Endgeräten mittels IEEE 802.1X

Neben der Absicherung administrativer Zugriffe wurde in der Testumgebung auch der Netzwerkzugang von Endgeräten kontrolliert. Hierfür wird der Standard IEEE 802.1X verwendet, der eine portbasierte Authentifizierung von Geräten an Access-Switchports ermöglicht.

Bei der portbasierten Authentifizierung wird der Zugriff auf einen Switchport zunächst blockiert, bis sich ein angeschlossenes Gerät erfolgreich authentifiziert hat. Erst nach erfolgreicher Authentifizierung wird der Port freigeschaltet und das Gerät erhält Zugriff auf das Netzwerk. Dadurch wird verhindert, dass unbekannte oder nicht autorisierte Geräte automatisch Zugang zum internen Netzwerk erhalten.

Ein 802.1X-System besteht aus drei zentralen Komponenten: dem Endgerät (Supplicant), dem Access-Switch (Authenticator) und einem Authentifizierungsserver. In der aufgebauten Infrastruktur übernimmt die Cisco Identity Services Engine die Rolle des Authentifizierungsservers. Der Switch kontrolliert den Zugriff auf den Port und leitet Authentifizierungsanfragen über das RADIUS-Protokoll an die ISE weiter.

Der Authentifizierungsprozess läuft in mehreren Schritten ab. Nach dem Anschluss eines Endgeräts bleibt der Switchport zunächst im nicht autorisierten Zustand. Das Endgerät startet anschließend den 802.1X-Authentifizierungsprozess und übermittelt seine Zugangsdaten über EAP. Der Switch leitet diese Informationen an die Cisco Identity Services Engine weiter, welche die Authentifizierung und Autorisierung gemäß den definierten Richtlinien durchführt. Nach einer erfolgreichen Authentifizierung wird der Port freigeschaltet und dem Gerät ein bestimmtes VLAN zugewiesen.
Dieser Ablauf wird im folgenden Diagramm dargestellt:

#figure(
  image("../assets/dot1x_ablauf.png", width: 100%),
  caption: [802.1x Ablauf],
)

Die Autorisierung der Endgeräte erfolgt über Richtlinien innerhalb der Cisco Identity Services Engine. Dort können Authentifizierungs- und Autorisierungspolicies definiert werden, anhand derer entschieden wird, welche Berechtigungen ein Gerät nach erfolgreicher Authentifizierung erhält.

#figure(
  image("../assets/ise_authz_policy.png", width: 100%),
  caption: [ISE Authorization Policy],
)

Bei der obigen Abbildung Handelt es sich um die Authorization Policy, welche verwendet wird, um Endgeräte über 802.1x zu autorisieren. Es gibt drei mögliche Situationen:

- Der Benutzer, welcher die Anfrage stellt, ist Teil der `dn-admins` Gruppe: #linebreak()
  Hier wird dem Switchport das Management-VLAN 99 zugewiesen. Der Benutzer kann sich somit administrativ auf Netzwerkgeräte verbinden.
- Der Benutzer ist Teil der `ALL_ACCOUNTS` Gruppe: #linebreak()
  Das VLAN 10, welches für reguläre Benutzer gedacht ist, wird am Switchport aktiv.
- Der Benutzername ist dem System nicht bekannt oder das Kennwort ist falsch: #linebreak()
  Der Switchport bleibt im unautorisierten Zustand.

Auf den Access-Switches wird 802.1X aktiviert und der Switchport als Authenticator konfiguriert. Dies ist mit folgendem Skript möglich:
#htl3r.code(
  caption: [Auszug der 802.1X-Konfiguration auf einem Access-Switch],
  description: `Cisco IOS Script`,
)[
  ```cisco
  dot1x system-auth-control

  int g1/0/5
    switchport mode access
    authentication port-control auto

    dot1x pae authenticator

    spanning-tree portfast
  ```
]

Nach erfolgreicher Authentifizierung kann der Status eines Ports über entsprechende Befehle überprüft werden. Auf Cisco-Switches liefert der Befehl `show authentication sessions interface` detaillierte Informationen über den aktuellen Authentifizierungszustand eines Ports:

#htl3r.code(
  caption: [Ausgabe eines Befehls zur Überprüfung von Authentifizierungen],
  description: `Cisco IOS Script`,
)[
  ```
  ASW1#sh authentication sessions interface g1/0/5 details
            Interface:  GigabitEthernet1/0/5
          MAC Address:  00e0.4c74.95e9
         IPv6 Address:  Unknown
         IPv4 Address:  10.0.99.8
            User-Name:  benedikt
               Status:  Authorized
               Domain:  DATA
       Oper host mode:  single-host
     Oper control dir:  both
      Session timeout:  N/A
      Restart timeout:  N/A
       Session Uptime:  140s
    Common Session ID:  0A0063020000001ED298E33E
      Acct Session ID:  0x00000010
               Handle:  0xF900000B
       Current Policy:  POLICY_Gi1/0/5

  Local Policies:
    Service Template: DEFAULT_LINKSEC_POLICY_SHOULD_SECURE (priority 150)

  Server Policies:
            Vlan Group:  Vlan: 99

  Method status list:
        Method           State

        dot1x            Authc Success

  ```
]

Die Ausgabe zeigt unter anderem den verwendeten Benutzer sowie den aktuellen Status der Sitzung und das zugewiesene VLAN. Auf diese Weise kann überprüft werden, ob ein Endgerät erfolgreich über IEEE 802.1X authentifiziert wurde und Zugriff auf das Netzwerk erhalten hat.

=== Zusammenfassung

In diesem Kapitel wurde die Absicherung des Netzwerkzugriffs in der aufgebauten Testumgebung beschrieben. Ziel der implementierten Maßnahmen war es, sowohl administrative Zugriffe auf Netzwerkgeräte als auch den Zugang von Endgeräten zum Netzwerk zentral zu kontrollieren und abzusichern. Zu diesem Zweck wurde eine Network-Access-Control-Architektur auf Basis der Cisco Identity Services Engine umgesetzt. Die ISE übernimmt dabei die zentrale Rolle für Authentifizierung, Autorisierung und Protokollierung von Zugriffen.

Durch diese Infrastruktur wird eine deutlich höhere Sicherheit im Netzwerk erreicht. Gleichzeitig wird eine konsistente Verwaltung von Benutzern, Geräten und Zugriffspolicies im Sinne einer Single Source of Truth ermöglicht.
