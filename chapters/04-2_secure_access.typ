#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Benedikt Theuretzbachner")
== Absicherung des Netzwerkzugriffs
In klassischen Netzwerkinfrastrukturen erfolgt der Zugriff auf das Netzwerk häufig ausschließlich über die physische Verbindung zu einem Switchport. Wird ein Gerät an einen aktiven Port angeschlossen, erhält es in vielen Fällen unmittelbar Zugang zum internen Netzwerk. Diese Vorgehensweise stellt ein erhebliches Sicherheitsrisiko dar, da nicht überprüft wird, ob es sich bei dem angeschlossenen Gerät um ein berechtigtes Endgerät handelt.

Ein ähnliches Problem besteht bei der administrativen Anmeldung auf Netzwerkkomponenten. Werden lokale Benutzerkonten auf Routern und Switches verwendet, müssen Zugangsdaten auf jedem Gerät einzeln verwaltet werden. Änderungen von Passwörtern oder Benutzerrechten müssen somit auf allen Geräten separat durchgeführt werden. Dies erhöht nicht nur den administrativen Aufwand, sondern erschwert auch die Nachvollziehbarkeit von Zugriffen.

Zur Verbesserung der Netzwerksicherheit wurde daher eine zentrale Lösung zur Absicherung des Netzwerkzugriffs implementiert. Ziel dieser Lösung ist es, sowohl den Zugriff von Administratoren auf Netzwerkgeräte als auch den Zugriff von Endgeräten auf das Netzwerk zu kontrollieren und zentral zu verwalten.

Die Umsetzung erfolgt mittels einer #htl3r.full[nac]-Lösung auf Basis der Cisco #htl3r.short[ise]. Dabei werden zwei zentrale Mechanismen eingesetzt:

- Authentifizierung von Administratoren auf Netzwerkgeräten über das #htl3r.long[radius]-Protokoll
- Authentifizierung von Endgeräten an Access-Switchports mittels #htl3r.short[ieee] #htl3r.short[dot1x]

Ein wesentliches Ziel dieser Architektur ist eine Single Source of Truth für Authentifizierungs- und Autorisierungsinformationen. Dabei werden Benutzerkonten, Geräteinformationen sowie Zugriffsrichtlinien nicht mehr lokal auf einzelnen Netzwerkgeräten gespeichert, sondern zentral durch die Cisco #htl3r.short[ise] verwaltet. Änderungen an Zugriffsrechten oder Richtlinien müssen dadurch nur an einer Stelle vorgenommen werden und gelten sofort für alle angebundenen Netzwerkkomponenten.

Die im Rahmen der Testumgebung implementierte Lösung verfolgt somit mehrere Ziele:

- Erhöhung der Netzwerksicherheit durch kontrollierten Netzwerkzugang
- Zentrale Authentifizierung von Administratoren auf Netzwerkgeräten über #htl3r.short[radius]
- Authentifizierung von Endgeräten über #htl3r.short[ieee] #htl3r.short[dot1x]
- Dynamische Zuweisung von #htl3r.longpl[vlan] auf Basis definierter Richtlinien
- Zentrale Verwaltung von Benutzern, Geräten und Zugriffspolicies im Sinne einer Single Source of Truth

Die folgenden Abschnitte erläutern zunächst die grundlegenden Konzepte von #htl3r.short[nac] sowie die Funktionsweise der eingesetzten Technologien. Anschließend wird die konkrete Umsetzung der Authentifizierungsmechanismen in der aufgebauten Testumgebung beschrieben.

=== Network Access Control

#htl3r.short[nac] bezeichnet ein Sicherheitskonzept zur Kontrolle des Zugriffs auf ein Netzwerk. Ziel von #htl3r.short[nac] ist es, sicherzustellen, dass nur berechtigte Benutzer und Geräte Zugriff auf Netzwerkressourcen erhalten. Dabei wird der Netzwerkzugang nicht mehr ausschließlich durch die physische Verbindung zu einem Switchport bestimmt, sondern durch eine Authentifizierungs- und Autorisierungsprüfung.

Ein typisches #htl3r.short[nac]-System besteht aus drei zentralen Komponenten:

- einem Endgerät, das Zugriff auf das Netzwerk anfordert
- einem Netzwerkgerät, das den Zugriff kontrolliert
- einem zentralen Authentifizierungsserver, der die Entscheidung über den Zugriff trifft

Das Endgerät wird als #htl3r.long[supplicant] bezeichnet. Dabei handelt es sich beispielsweise um einen Laptop oder einen Arbeitsplatzrechner, der mit dem Netzwerk verbunden wird. Das Netzwerkgerät, üblicherweise ein Access-Switch, übernimmt die Rolle des #htl3r.long[authenticator]. Dieser kontrolliert den Zugriff auf den jeweiligen Switchport und leitet Authentifizierungsanfragen an den zentralen Authentifizierungsserver weiter. Der Authentifizierungsserver überprüft die Identität des Benutzers oder Geräts und entscheidet auf Basis definierter Richtlinien, ob der Zugriff auf das Netzwerk erlaubt wird.

#figure(
  image("../assets/nac_diagram.png", width: 100%),
  caption: [Abbildung der NAC-Rollen],
)

In der hier aufgebauten Testumgebung übernimmt die Cisco #htl3r.short[ise], auf welche später noch genauer eingegangen wird, die Rolle des zentralen Authentifizierungsservers. Die Access-Switches fungieren als #htl3r.longpl[authenticator] und setzen die vom Authentifizierungsserver getroffenen Entscheidungen auf den jeweiligen Switchports um.

Ein grundlegendes Konzept im Zusammenhang mit #htl3r.short[nac] ist das #htl3r.full[aaa]-Modell, das drei zentrale Funktionen der Zugriffskontrolle in Netzwerken beschreibt:

- *Authentication* bezeichnet die Überprüfung der Identität eines Benutzers oder Geräts. Dabei wird festgestellt, ob die angegebene Identität gültig ist. Dies kann beispielsweise durch Benutzername und Passwort, Zertifikate oder andere Authentifizierungsarten erfolgen.

- *Authorization* beschreibt die Entscheidung darüber, welche Rechte einem authentifizierten Benutzer oder Gerät im Netzwerk gegeben werden. Nach erfolgreicher Authentifizierung kann der Zugriff beispielsweise auf bestimmte Netzwerksegmente beschränkt oder ein bestimmtes #htl3r.short[vlan] zugewiesen werden.

- *Accounting* dient der Protokollierung und Nachvollziehbarkeit von Zugriffen. Dabei werden Authentifizierungsereignisse, Sitzungen sowie Netzwerkzugriffe protokolliert. Diese Informationen können für Sicherheitsanalysen, Fehlersuche oder Auditing-Zwecke verwendet werden.

Durch die Kombination von #htl3r.short[nac], dem #htl3r.short[aaa]-Modell und einem zentralen Authentifizierungsserver wird eine kontrollierte und nachvollziehbare Zugriffssteuerung im Netzwerk ermöglicht. Zugriff auf das Netzwerk erhalten nur Benutzer und Geräte, die erfolgreich authentifiziert wurden und deren Zugriff durch definierte Richtlinien autorisiert wurde.

=== Cisco Identity Services Engine

Die Cisco #htl3r.short[ise] dient in der aufgebauten Testumgebung als zentrale Plattform zur Verwaltung von Authentifizierungs- und Autorisierungsprozessen. Über die #htl3r.short[ise] werden Benutzer, Netzwerkgeräte sowie Zugriffsrichtlinien zentral verwaltet und kontrolliert.
Als Hardwareplattform kommt ein Server des Typs Cisco #htl3r.full[ucs] C220 M4 zum Einsatz. Dabei handelt es sich um einen Rack-Server aus der #htl3r.short[ucs] Produktfamilie, der für den Betrieb von Infrastrukturservices und Netzwerkmanagementsystemen ausgelegt ist.

In der Testumgebung wird die #htl3r.short[ise] für zwei zentrale Aufgaben eingesetzt. Einerseits übernimmt sie die Authentifizierung von Administratoren, die sich über das #htl3r.full[radius]-Protokoll auf Netzwerkgeräten anmelden. Andererseits wird sie für die Authentifizierung von Endgeräten an Access-Switchports mittels #htl3r.full[ieee] #htl3r.full[dot1x] verwendet. Die Netzwerkgeräte fungieren dabei als #htl3r.short[radius]-Clients und leiten Authentifizierungsanfragen an die #htl3r.short[ise] weiter.


Die Administration erfolgt über eine webbasierte Oberfläche, über die Richtlinien definiert, Netzwerkgeräte registriert sowie Authentifizierungsereignisse überwacht werden können.

In folgender Abbildung ist das Dashboard der #htl3r.short[ise] zu sehen:

#figure(
  image("../assets/ise-dashboard.png", width: 100%),
  caption: [Abbildung des ISE-Dashboards],
)

Im weiteren Verlauf dieses Kapitels wird beschrieben, wie die #htl3r.short[ise] zur Absicherung administrativer Zugriffe sowie zur Authentifizierung von Endgeräten mittels #htl3r.short[ieee] #htl3r.short[dot1x] eingesetzt wurde.

=== Authentifizierung von Netzwerkadministratoren über RADIUS

In der Testumgebung wurde die administrative Anmeldung auf Netzwerkkomponenten an einen zentralen Punkt ausgelagert. Administratoren greifen typischerweise über #htl3r.short[ssh] auf Router und Switches zu, um Konfigurationen vorzunehmen oder den Zustand der Geräte zu überprüfen.
Anstatt lokale Benutzerkonten auf jedem einzelnen Netzwerkgerät zu verwalten, werden Authentifizierungsanfragen an einen #htl3r.short[radius]-Server weitergeleitet. In der aufgebauten Infrastruktur übernimmt die Cisco #htl3r.short[ise] diese Rolle. Netzwerkgeräte fungieren dabei als #htl3r.short[radius]-Clients und übermitteln Anmeldeversuche an die #htl3r.short[ise], welche die Authentifizierung sowie die zugehörige Autorisierung gemäß den definierten Policies durchführt.

Durch diese zentrale Authentifizierung können Benutzerkonten und Zugriffsrechte an einer Stelle verwaltet werden. Änderungen an Benutzerkonten müssen nicht mehr auf jedem Gerät einzeln vorgenommen werden, sondern werden unmittelbar für alle angebundenen Netzwerkgeräte wirksam.
Ein weiterer zentraler Vorteil dieser Architektur ist, dass Logs einheitlich protokolliert und an einem Punkt ersichtlich sind. In der folgenden Abbildung sind zwei Anmeldeversuche zu erkennen. Beide wurden an demselben Netzwerkgerät durchgeführt, jedoch ist der zweite fehlgeschlagen, da die verwendete Richtlinie nur Benutzer einer bestimmten Gruppe authentifiziert:

#figure(
  image("../assets/ise-logs.png", width: 100%),
  caption: [ISE Live Logs],
)

Damit Netzwerkgeräte Authentifizierungsanfragen an die Cisco #htl3r.short[ise] weiterleiten können, müssen sie als #htl3r.short[radius]-Clients konfiguriert werden. Dazu wird auf dem jeweiligen Gerät der #htl3r.short[radius]-Server definiert und anschließend für die Authentifizierung der Managementzugänge verwendet.

In folgendem Beispiel wird der #htl3r.short[radius]-Server auf der Firewall ZBFW-1 definiert:

#htl3r.code(
  caption: [Auszug aus der Firewall Konfiguration],
  description: `Cisco IOS Skript`,
)[
  ```cisco
  radius server ISE
    address ipv4 10.0.99.10 auth-port 1812 acct-port 1813
    key <hier wurde das Passwort eingefügt>
  ```
]

Die verwendeten Ports sowie das Passwort wurden im Vorhinein auf der #htl3r.short[ise] festgelegt.

In dieser Konfiguration werden Anmeldeversuche zunächst an den zentralen #htl3r.short[radius]-Server weitergeleitet. Ist dieser nicht erreichbar, kann optional ein lokaler Benutzer als Fallback verwendet werden. Auf diese Weise wird eine zentrale Verwaltung administrativer Zugriffe ermöglicht, ohne die Erreichbarkeit der Geräte im Fehlerfall zu verlieren.

=== Authentifizierung von Endgeräten mittels IEEE 802.1X

Neben der Absicherung administrativer Zugriffe wurde in der Testumgebung auch der Netzwerkzugang von Endgeräten kontrolliert. Hierfür wird der Standard #htl3r.short[ieee] #htl3r.short[dot1x] verwendet, der eine portbasierte Authentifizierung an Access-Switchports ermöglicht. Ein Switchport bleibt dabei zunächst blockiert und wird erst nach erfolgreicher Authentifizierung für den Netzwerkzugriff freigeschaltet.

Ein #htl3r.short[dot1x]-System besteht aus drei Komponenten: dem Endgerät (#htl3r.long[supplicant]), dem Access-Switch (#htl3r.long[authenticator]) und einem Authentifizierungsserver. In der aufgebauten Infrastruktur übernimmt die Cisco #htl3r.short[ise] diese Rolle. Der Switch kontrolliert den Zugriff auf den Port und leitet Authentifizierungsanfragen über #htl3r.short[radius] an die #htl3r.short[ise] weiter.

Nach dem Anschluss eines Endgeräts startet der #htl3r.short[dot1x]-Authentifizierungsprozess. Das Endgerät übermittelt seine Zugangsdaten über das #htl3r.full[eap], welche vom Switch an die #htl3r.short[ise] weitergeleitet werden. Nach erfolgreicher Authentifizierung wird der Port freigeschaltet und dem Gerät ein entsprechendes #htl3r.short[vlan] zugewiesen. Der Ablauf ist in der folgenden Abbildung dargestellt:

#figure(
  image("../assets/dot1x_ablauf.png", width: 100%),
  caption: [802.1X Ablauf],
)

Die Autorisierung der Endgeräte erfolgt über Richtlinien innerhalb der #htl3r.short[ise]. Dort können Authentifizierungs- und Autorisierungspolicies definiert werden, anhand derer entschieden wird, welche Berechtigungen ein Gerät nach erfolgreicher Authentifizierung erhält.

#figure(
  image("../assets/ise_authz_policy.png", width: 100%),
  caption: [ISE Authorization Policy],
)

Bei der obigen Abbildung handelt es sich um die Authorization Policy, welche verwendet wird, um Endgeräte über #htl3r.short[dot1x] zu autorisieren. Es gibt drei mögliche Situationen:

- Der Benutzer, welcher die Anfrage stellt, ist Teil der `dn-admins` Gruppe: #linebreak()
  Hier wird dem Switchport das Management-#htl3r.short[vlan] 99 zugewiesen. Der Benutzer kann sich somit administrativ auf Netzwerkgeräte verbinden.
- Der Benutzer ist Teil der `ALL_ACCOUNTS` Gruppe: #linebreak()
  Das #htl3r.short[vlan] 10, welches für reguläre Benutzer gedacht ist, wird am Switchport aktiv.
- Der Benutzername ist dem System nicht bekannt oder das Kennwort ist falsch: #linebreak()
  Der Switchport bleibt im unautorisierten Zustand.

Auf den Access-Switches wurde #htl3r.short[dot1x] aktiviert und der Switchport als #htl3r.long[authenticator] konfiguriert. Dies ist mit folgendem Skript möglich:
#htl3r.code(
  caption: [Auszug der 802.1X-Konfiguration auf einem Access-Switch],
  description: `Cisco IOS Skript`,
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

Nach erfolgreicher Authentifizierung kann der Status eines Ports durch entsprechende Befehle überprüft werden. Auf Cisco-Switches liefert der Befehl `show authentication sessions interface` detaillierte Informationen über den aktuellen Authentifizierungszustand eines Ports:

#htl3r.code(
  caption: [Ausgabe eines Befehls zur Überprüfung von Authentifizierungen],
  description: `Cisco IOS Skript`,
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

Die Ausgabe zeigt unter anderem den verwendeten Benutzer sowie den aktuellen Status der Sitzung und das zugewiesene #htl3r.short[vlan]. Auf diese Weise kann überprüft werden, ob ein Endgerät erfolgreich über #htl3r.short[ieee] #htl3r.short[dot1x] authentifiziert wurde und Zugriff auf das Netzwerk erhalten hat.

=== Zusammenfassung

In diesem Kapitel wurde die Absicherung des Netzwerkzugriffs in der aufgebauten Testumgebung beschrieben. Ziel der implementierten Maßnahmen war es, sowohl administrative Zugriffe auf Netzwerkgeräte als auch den Zugang von Endgeräten zum Netzwerk zentral zu kontrollieren und abzusichern. Zu diesem Zweck wurde eine #htl3r.short[nac]-Architektur auf Basis der Cisco #htl3r.short[ise] umgesetzt. Die #htl3r.short[ise] übernimmt dabei die zentrale Rolle für Authentifizierung, Autorisierung und Protokollierung von Zugriffen.

Durch diese Infrastruktur wird eine deutlich höhere Sicherheit im Netzwerk erreicht. Gleichzeitig wird eine konsistente Verwaltung von Benutzern, Geräten und Zugriffspolicies im Sinne einer Single Source of Truth ermöglicht.
