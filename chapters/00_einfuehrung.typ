#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Danijel Stamenkovic")

= Einführung in DiagNet

Beim Betrieb größerer Netzwerkinfrastrukturen tritt häufig ein bekanntes Problem auf. Zu Beginn wird ein Netzwerk sorgfältig geplant, konfiguriert und dokumentiert. In diesem Moment entspricht die tatsächliche Konfiguration genau dem vorgesehenen Design und alle Komponenten funktionieren wie erwartet.

Im laufenden Betrieb verändert sich dieser Zustand jedoch schrittweise. Software-Updates werden installiert, kurzfristige Anpassungen an der Konfiguration vorgenommen oder neue Geräte in das Netzwerk integriert. Solche Änderungen sind im Alltag von IT-Infrastrukturen unvermeidbar. Mit der Zeit kann jedoch der Überblick darüber verloren gehen, ob alle Einstellungen noch dem ursprünglichen Konzept entsprechen.

Dadurch entstehen häufig Unsicherheiten. Beispielsweise ist nicht immer klar, ob sicherheitsrelevante Funktionen wie #htl3r.full[dhcp] Snooping weiterhin auf allen Access-Switches aktiviert sind oder ob bestimmte Parameter im Spanning-Tree-Protokoll noch korrekt gesetzt sind. Besonders in größeren Netzwerken mit vielen Geräten kann die manuelle Überprüfung solcher Konfigurationen schnell sehr aufwendig werden.

In der Praxis erfolgt diese Kontrolle meist über eine standardmäßige Verbindung zu den jeweiligen Geräten, etwa per #htl3r.full[ssh]. Administratoren führen anschließend verschiedene Diagnosebefehle aus und vergleichen deren Ausgabe mit der vorhandenen Dokumentation. Dieser Prozess ist zwar grundsätzlich zuverlässig, jedoch zeitintensiv und anfällig für menschliche Fehler.

Um diese Problematik zu adressieren, wurde im Rahmen dieser Diplomarbeit die Anwendung #htl3r.long[diagnet] entwickelt. Ziel des Projekts ist es, die Überprüfung von Netzwerkzuständen zu automatisieren und dadurch schneller sowie konsistenter durchführen zu können. Durch definierte Testfälle können Konfigurationen automatisch überprüft und mögliche Abweichungen vom geplanten Design frühzeitig erkannt werden.

#pagebreak()

== Das Konzept für die Automatisierung

Die zentrale Idee hinter #htl3r.long[diagnet] besteht darin, typische Überprüfungen von Netzwerkkonfigurationen in Form automatisierter Tests abzubilden. Statt jede Konfiguration manuell zu kontrollieren, werden diese Prüfungen durch ein System durchgeführt, das selbstständig mit den Netzwerkgeräten kommuniziert.

Hierfür werden strukturierte Testfälle definiert, die bestimmte Eigenschaften eines Netzwerks überprüfen. Ein solcher Test kann beispielsweise kontrollieren, ob eine Routing-Nachbarschaft aktiv ist, ob ein bestimmtes #htl3r.full[vlan] existiert oder ob Sicherheitsmechanismen korrekt konfiguriert wurden.

Die Ergebnisse dieser Prüfungen werden anschließend automatisch ausgewertet und gespeichert. Dadurch entsteht ein klarer Überblick über den aktuellen Zustand der Netzwerkumgebung. Gleichzeitig können Veränderungen zwischen verschiedenen Testläufen leichter erkannt werden.

Ein weiterer Vorteil dieses Ansatzes liegt in der Standardisierung. Da alle Tests nach demselben Schema aufgebaut sind, lassen sich Prüfungen wiederholen und auf verschiedene Geräte anwenden. Dies reduziert den manuellen Aufwand erheblich und erhöht gleichzeitig die Konsistenz der Ergebnisse.

Grundlage jedes Testfalls ist dabei ein Soll-Ist-Vergleich. Der erwartete Zustand einer Konfiguration wird vorab definiert und anschließend mit dem tatsächlich auf dem Gerät vorgefundenen Zustand verglichen. Stimmen beide überein, gilt der Test als erfolgreich. Weichen sie voneinander ab, wird dies als Fehler gewertet und entsprechend protokolliert. Dieses Prinzip macht Abweichungen vom gewünschten Netzwerkzustand eindeutig erkennbar und nachvollziehbar.

Die Kommunikation mit den Netzwerkgeräten erfolgt dabei weiterhin über #htl3r.full[ssh] oder Telnet, wodurch keine zusätzliche Software auf den Geräten installiert werden muss. Das System verbindet sich jedoch automatisch mit den definierten Geräten, führt die notwendigen Diagnosebefehle aus und wertet die zurückgegebenen Ausgaben strukturiert aus. Dadurch bleibt die bestehende Netzwerkinfrastruktur unverändert und die Integration von #htl3r.long[diagnet] gestaltet sich unkompliziert.

#pagebreak()

== Die Schwerpunkte von DiagNet

Die Entwicklung von #htl3r.long[diagnet] konzentriert sich auf mehrere zentrale Aspekte, die für den praktischen Einsatz in Netzwerkumgebungen relevant sind.

Ein wichtiger Schwerpunkt ist die Automatisierung von Netzwerktests. Durch automatisierte Prüfungen können Konfigurationsfehler schneller erkannt werden als bei manuellen Kontrollen. Besonders bei größeren Netzwerken mit vielen Geräten bietet dies einen deutlichen Vorteil.

Ein weiterer Fokus liegt auf der Übersichtlichkeit der Ergebnisse. Die Resultate der Testläufe werden in einer webbasierten Oberfläche dargestellt, sodass Administratoren den Zustand des Netzwerks auf einen Blick erkennen können. Grafische Darstellungen und übersichtliche Tabellen erleichtern dabei die Analyse der Ergebnisse.

Darüber hinaus spielt auch die Modularität der Anwendung eine wichtige Rolle. Neue Testfälle können flexibel hinzugefügt werden, ohne dass die gesamte Anwendung angepasst werden muss. Dadurch lässt sich das System an unterschiedliche Netzwerkumgebungen und Anforderungen anpassen.

Ein weiterer wichtiger Punkt ist die Nachvollziehbarkeit von Änderungen. Durch die Speicherung von Testergebnissen können verschiedene Testläufe miteinander verglichen werden. Auf diese Weise wird sichtbar, ob sich der Zustand des Netzwerks im Laufe der Zeit verändert hat.

Ebenso wurde bei der Entwicklung auf eine möglichst einfache Bedienbarkeit geachtet. Testfälle lassen sich über eine webbasierte Oberfläche konfigurieren, ohne dass dabei Programmierkenntnisse erforderlich sind. Dies ermöglicht es auch Netzwerkadministratoren ohne Softwareentwicklungshintergrund, eigene Prüfungen zu erstellen und zu verwalten.

Schließlich wurde das System von Beginn an auf Skalierbarkeit ausgelegt. Wächst eine Netzwerkumgebung, können weitere Geräte und Testfälle ohne strukturelle Änderungen an der Anwendung ergänzt werden. Damit eignet sich #htl3r.long[diagnet] sowohl für kleinere Laborumgebungen als auch für den Einsatz in größeren, produktiven Netzwerkinfrastrukturen.

#pagebreak()

== Projektrealisierung und Kooperation

Das Projekt #htl3r.long[diagnet] entstand im Rahmen der Diplomarbeit an der Höheren Technischen Bundeslehranstalt Wien 3 Rennweg im Ausbildungsschwerpunkt Informationstechnologie mit Fokus auf Netzwerktechnik. Die Arbeit wurde von mehreren Schülern gemeinsam umgesetzt und im Schuljahr 2025/26 durchgeführt. Ziel des Projekts war es, eine praktische Lösung für ein reales Problem im Bereich der Netzwerkadministration zu entwickeln.

Unterstützt wurde das Projekt durch den Kooperationspartner CANCOM Austria AG, der Hardware für das Laborumfeld zur Verfügung stellte. Dadurch konnte die entwickelte Software nicht nur in einer simulierten Umgebung getestet werden, sondern auch mit realen Netzwerkgeräten. Im Verlauf der Arbeit wurde sowohl die Infrastruktur für die Tests aufgebaut als auch die Softwareplattform entwickelt, die die automatisierten Prüfungen durchführt. Das Ergebnis ist eine funktionierende Open-Source-Applikation, die zur Analyse und Überprüfung von Netzwerkkonfigurationen eingesetzt werden kann.

Die Applikation steht unter der GNU General Public License Version 3 oder höher (GPLv3+) und kann frei verwendet, verändert und weitergegeben werden. Sie wird ohne Gewährleistung bereitgestellt.
