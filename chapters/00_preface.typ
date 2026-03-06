#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Karun Sandhu")
= Einführung in DiagNet

Dieses einleitende Kapitel bietet einen übergeordneten Blick auf unsere Diplomarbeit. Es beleuchtet die grundlegende Motivation hinter dem Projekt, die Kernfunktionen der von uns entwickelten Software sowie den praktischen Mehrwert, den eine automatisierte Diagnose für moderne IT-Infrastrukturen bietet. Das Ziel ist es, das grundlegende Konzept von DiagNet verständlich einzuordnen, bevor in den folgenden Kapiteln die tiefergehenden technischen Details und Architekturentscheidungen behandelt werden.

== Die unsichtbare Infrastruktur
In der heutigen Zeit bilden Computernetzwerke das digitale Nervensystem nahezu jedes Unternehmens. Solange alles funktioniert, bleibt diese komplexe Infrastruktur für die meisten Menschen unsichtbar. Wenn IT-Techniker jedoch Änderungen vornehmen, sei es das Austauschen eines Geräts oder das Anpassen von Sicherheitsrichtlinien, stellt sich eine zentrale Frage: Wie lässt sich mit Sicherheit sagen, dass durch die neue Konfiguration nicht versehentlich an einer anderen Stelle etwas beschädigt wurde?

Bisher gleicht die Beantwortung dieser Frage oft der sprichwörtlichen Suche nach der Nadel im Heuhaufen. Techniker müssen sich manuell auf unzähligen Geräten einloggen und kryptische Befehle in schwarze Textfenster eintippen, um die Verbindungen zu prüfen. Das kostet nicht nur enorm viel Zeit, sondern ist auch stark abhängig von der Tagesform und dem individuellen Wissen der ausführenden Person.

== DiagNet als digitale Test-Suite
An genau diesem Punkt setzt unsere Diplomarbeit an. Mit DiagNet haben wir eine automatisierte, zentrale Test-Suite entwickelt. Anstatt mühsam hunderte Befehle von Hand abzutippen, bietet unsere Applikation eine übersichtliche Weboberfläche. Über dieses Dashboard können Netzwerkadministratoren ihre Geräte verwalten und gezielte Testfälle wie auf einem digitalen Prüfstand zusammenstellen.

DiagNet fungiert dabei als verlässliches On-Demand-Diagnosewerkzeug. Wenn ein Techniker Wartungsarbeiten am Netzwerk abgeschlossen hat, kann er mit einem einfachen Knopfdruck eine vordefinierte Reihe von Tests auslösen. Das System baut im Hintergrund vollautomatisch die Verbindungen zu den Geräten auf, führt die Prüfungen durch und meldet anschaulich zurück, ob alle konfigurierten Anforderungen (wie beispielsweise die Erreichbarkeit eines bestimmten Servers) erfüllt sind.

== Historie und Nachvollziehbarkeit
Ein entscheidender Vorteil unseres Systems ist das Führen einer digitalen Historie. Jeder durchgeführte Testlauf wird samt seinem Ergebnis dauerhaft in einer Datenbank gespeichert. Für Personen, die das Netzwerk betreuen, ist dies ein unschätzbarer Mehrwert: Tritt heute ein Fehler auf, lässt sich sofort nachvollziehen, ob derselbe Testfall gestern oder vor einer Woche noch erfolgreich war.

Durch diese Abstraktion wandelt sich die fehleranfällige und oft unzureichend dokumentierte Handarbeit in einen reproduzierbaren, standardisierten Prozess. DiagNet reduziert die Komplexität der Netzwerkdiagnose drastisch und macht es selbst weniger erfahrenen Technikern möglich, komplexe Infrastrukturen sicher zu überprüfen.

== Entstehung und Kooperation
Die initiale Idee, ein solches System für die Gesundheitsprüfung von Netzwerken zu entwerfen, stammt von der CANCOM Austria AG. Das IT-Unternehmen hat unsere Diplomarbeit als externer Kooperationspartner begleitet und uns essenzielle Hardware für den Aufbau unserer Testumgebung zur Verfügung gestellt.

Wir möchten an dieser Stelle betonen, dass die gesamte Konzeption, die Programmierung sowie die Absicherung der Applikation eigenverantwortlich durch unser Projektteam erfolgt sind. DiagNet wird als Open-Source-Projekt unter der GPLv3+-Lizenz veröffentlicht. Entsprechend den Bedingungen dieser freien Lizenz wird die Software „as is“, also ohne jegliche Gewährleistung oder Garantie, bereitgestellt. Weder die CANCOM Austria AG als Impulsgeber noch wir als Autoren und Entwickler übernehmen eine juristische Haftung für die Code-Qualität, potenzielle Sicherheitslücken oder etwaige Schäden, die durch den Einsatz des Systems entstehen könnten. Diese Vorgehensweise erlaubt es uns, reale Anforderungen aus der Industrie umzusetzen und die Applikation der Allgemeinheit frei zur Verfügung zu stellen, ohne dabei rechtliche Risiken einzugehen.
