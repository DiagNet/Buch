// Has to be imported for function use
#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Luka Pacar")
= Erstellung von Testfällen
Das Backend definiert die logische Struktur und die Ausführung der Tests. Der Anwender benötigt jedoch eine grafische Schnittstelle zur Bedienung. Die technische Herausforderung liegt in der Übersetzung der Python Definitionen in ein interaktives Formular. DiagNet löst diese Aufgabe durch einen automatischen Formulargenerator. Damit dieser dynamische Austausch reibungslos funktioniert müssen Frontend und Backend über mehrere dedizierte API Schnittstellen kommunizieren.

Der Prozess der Testerstellung gliedert sich hierbei in drei Phasen. Zunächst erfolgt die Auswahl des Testfalls aus dem verfügbaren Portfolio. Daran schließt sich die Definition der Parameter an wobei das System die Eingabemaske basierend auf der Testklasse generiert. Abschließend werden die Testmetadaten verarbeitet und der Testfall erstellt.

== Auswahl des Testfalls
Der Prozess der Testerstellung wird durch die Selektion eines Test Templates initiiert. Der Benutzer wählt hierbei aus einer Liste von verfügbaren Vorlagen welche die im Backend implementierten Testklassen repräsentieren. Das Frontend bezieht diese Auswahlmöglichkeiten dynamisch über eine API Schnittstelle vom Server.

Ein wesentlicher Bestandteil dieser Phase ist die Bereitstellung von Kontextinformationen. Sobald ein Template fokussiert wird ruft der Client die zugehörige Dokumentation ab. Das Backend extrahiert diese Beschreibung direkt aus den Docstrings der Python Klassen und übermittelt sie an die Benutzeroberfläche. Dies ermöglicht dem Anwender die Einsicht in die spezifische Funktionsweise und die Anforderungen des Tests noch vor der eigentlichen Konfiguration.

== Definition der Parameter
Nach dem Empfang der Metadaten generiert das Frontend die Eingabemaske. Da die Parameter unterschiedliche Anforderungen an Validierung und Darstellung stellen verwendet das System eine objektorientierte Architektur. Die abstrakte Basisklasse `Datatype` definiert hierbei die Schnittstelle für alle Datentypen. Eine statische Fabrikmethode `toDatatype` analysiert den vom Backend übermittelten Typenstring und instanziiert die korrekte Subklasse wie etwa `Device` oder `IPv4`.

```javascript
static toDatatype(datatype, parentParameter, conditions, allParameters) {
    switch (datatype.trim().toLowerCase()) {
      case "device":
        return new Device(conditions);
      case "ipv4":
        return new IPv4(conditions);
      // ... weitere Typen
      default:
        throw new Error("Datatype not found.");
    }
}
```
