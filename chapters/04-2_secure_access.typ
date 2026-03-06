#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Benedikt Theuretzbachner")
== Absicherung des Netzwerkzugriffs
In klassischen Netzwerkinfrastrukturen erfolgt der Zugriff auf das Netzwerk häufig ausschließlich über die physische Verbindung zu einem Switchport. Wird ein Gerät an einen aktiven Port angeschlossen, erhält es in vielen Fällen unmittelbar Zugang zum internen Netzwerk. Diese Vorgehensweise stellt ein erhebliches Sicherheitsrisiko dar, da nicht überprüft wird, ob es sich bei dem angeschlossenen Gerät um ein berechtigtes Endgerät handelt.

Ein ähnliches Problem besteht bei der administrativen Anmeldung auf Netzwerkkomponenten. Werden lokale Benutzerkonten auf Routern und Switches verwendet, müssen Zugangsdaten auf jedem Gerät einzeln verwaltet werden. Änderungen von Passwörtern oder Benutzerrechten müssen somit auf allen Geräten separat durchgeführt werden. Dies erhöht nicht nur den administrativen Aufwand, sondern erschwert auch die Nachvollziehbarkeit von Zugriffen.

Zur Verbesserung der Netzwerksicherheit wurde daher eine zentrale Lösung zur Absicherung des Netzwerkzugriffs implementiert. Ziel dieser Lösung ist es, sowohl den Zugriff von Administratoren auf Netzwerkgeräte als auch den Zugriff von Endgeräten auf das Netzwerk zu kontrollieren und zentral zu verwalten.

Die Umsetzung erfolgt mittels einer Network-Access-Control-Lösung auf Basis der Cisco Identity Services Engine (ISE). Dabei werden zwei zentrale Mechanismen eingesetzt:

- Authentifizierung von Administratoren auf Netzwerkgeräten über das RADIUS-Protokoll
- Authentifizierung von Endgeräten an Access-Switchports mittels IEEE 802.1X

Durch diese Architektur können Zugriffe auf das Netzwerk und auf Netzwerkgeräte zentral gesteuert werden. Gleichzeitig ermöglicht die zentrale Authentifizierungsinstanz eine konsistente Verwaltung von Benutzern, Richtlinien und Zugriffsrechten.

Ein wesentliches Ziel dieser Architektur ist außerdem eine Single Source of Truth für Authentifizierungs- und Autorisierungsinformationen. Dabei werden Benutzerkonten, Geräteinformationen sowie Zugriffsrichtlinien nicht mehr lokal auf einzelnen Netzwerkgeräten gespeichert, sondern zentral durch die Cisco Identity Services Engine verwaltet. Änderungen an Zugriffsrechten oder Richtlinien müssen dadurch nur an einer Stelle vorgenommen werden und gelten unmittelbar für alle angebundenen Netzwerkkomponenten.

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
  caption: [abbildung der NAC Rollen],
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

Die Cisco Identity Services Engine wird in der Testumgebung auf einem dedizierten Server betrieben. Als Hardwareplattform kommt ein Server des Typs Cisco UCS C220 M4 zum Einsatz. Dabei handelt es sich um einen Rack-Server aus der Cisco Unified Computing System (UCS) Produktfamilie, der für den Betrieb von Infrastrukturservices und Netzwerkmanagementsystemen ausgelegt ist. Die ISE läuft auf diesem System als Appliance und stellt sämtliche Funktionen zur Authentifizierung, Autorisierung und Protokollierung zentral bereit.

Durch den Einsatz der Cisco ISE können Authentifizierungs- und Autorisierungsrichtlinien zentral verwaltet werden. Änderungen an Benutzerkonten oder Zugriffsrichtlinien müssen nicht mehr auf einzelnen Netzwerkgeräten vorgenommen werden, sondern können an einer zentralen Stelle administriert werden. Dies vereinfacht die Verwaltung der Infrastruktur und reduziert gleichzeitig das Risiko von Inkonsistenzen in der Konfiguration.

#figure(
  caption: [Administrationsoberfläche der Cisco Identity Services Engine mit Policy- und Authentifizierungseinstellungen],
  placement: auto,
)[
  // Screenshot einfügen: ISE Web Interface (Policy Sets / Authentication Policy / Authorization Policy)
]

Die grafische Administrationsoberfläche der Cisco Identity Services Engine ermöglicht die Konfiguration von Authentifizierungs- und Autorisierungsrichtlinien sowie die Verwaltung von Netzwerkgeräten, Benutzern und Gruppen. Zusätzlich können über die Monitoring-Funktionen aktuelle Authentifizierungsereignisse und Systemmeldungen eingesehen werden.

Im weiteren Verlauf dieses Kapitels wird beschrieben, wie die Cisco Identity Services Engine konkret zur Absicherung administrativer Zugriffe auf Netzwerkgeräte sowie zur Authentifizierung von Endgeräten mittels IEEE 802.1X eingesetzt wurde.
