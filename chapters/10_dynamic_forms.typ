#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Luka Pacar")

= Dynamische Formulare <dynamic_forms>
Bei der Architektur von _#htl3r.long[diagnet]_ wurde großer Wert auf eine klare Trennung zwischen der Testlogik und der grafischen Oberfläche gelegt.
Während die Implementierung der Netzwerktests und deren Parameterdefinitionen ausschließlich in Python-Dateien vorliegt, muss die Benutzeroberfläche diese Strukturen abbilden können.
Da sich die erforderlichen Eingaben für jedes Testszenario stark unterscheiden, ist ein statisches #htl3r.full[html]-Formular keine Lösung.
Stattdessen generiert das System die Eingabefelder dynamisch, indem es die Struktur aus den empfangenen Testattributen ableitet.

== Aufbau der Benutzeroberfläche
Der Aufbau des Formulars beginnt, sobald der Anwender eine Testklasse auswählt.
Das System sendet eine Anfrage an die #htl3r.full[api] des Servers, um die Konfiguration des gewählten Tests zu laden.
Das Backend liest dabei die Attribute der Python-Klasse aus und wandelt sie in ein standardisiertes #htl3r.full[json]-Format um.
Dieses Datenobjekt dient als Bauplan für den Client und enthält neben den Parameternamen und Datentypen auch Informationen über Pflichtfelder sowie Abhängigkeiten zwischen den Eingabewerten.

Nach dem Empfang der Daten wird der Container für die Parameter vorbereitet und nötige Abhängigkeiten definiert.
In einer Schleife werden daraufhin alle Definitionen nacheinander abgearbeitet, in das entsprechende Eingabeelement übersetzt und in die Oberfläche integriert.
Dieser Ansatz entkoppelt das Frontend von der Programmierung der Tests.
Fügt ein Entwickler im Backend einen neuen Parameter hinzu, erscheint dieser automatisch in der Benutzeroberfläche, ohne dass der Code des Frontends angepasst werden muss.

== Abstraktion der Eingabefelder
Damit der Code wartbar bleibt, verzichtet das System auf komplexe Funktionen zur Erstellung der Felder. Stattdessen definiert eine abstrakte Basisklasse das Verhalten aller Eingabeelemente. Sie garantiert eine einheitliche Schnittstelle, unabhängig von der eigentlichen visuellen Darstellung.

Jedes Eingabefeld, ob Textfeld, Dropdown-Liste oder eine spezielle Auswahl für Netzwerkgeräte, muss von dieser Basisklasse erben. Das garantiert, dass der Code für das Parametermanagement jedes Feld gleich behandeln kann, ohne dessen interne Details zu kennen. Eine #htl3r.long[fabrikmethode] prüft den geforderten Datentyp und erstellt die passende Unterklasse.

Der folgende Code zeigt die Struktur dieser Abstraktion. Sie schreibt vor, dass jede Unterklasse Funktionen zur Erstellung des #htl3r.short[html]-Elements, zur Rückgabe des Werts und zur Überprüfung des Datentyps bereitstellen muss.

#htl3r.code(
  caption: [Struktur der Parameterklasse],
  description: `parameter_field.js`,
)[
  ```javascript
  class ParameterField {
    createField()      // Erstellt das DOM-Element für das Eingabefeld
    getValue()         // Gibt den aktuellen Wert des Feldes zurück
    checkDatatype()    // Validiert den Datentyp
  }
  ```
]

Durch diese Struktur kann das System entscheiden, welche Implementierung für einen Parameter notwendig ist. Listen-Parameter werden beispielsweise rekursiv behandelt, indem die Listen-Komponente wiederum Instanzen der Basisklasse für ihre Einträge verwaltet.

== Datentyp-Validierung
Neben der Darstellung muss auch die inhaltliche Korrektheit der eingegebenen Daten sichergestellt werden. Dafür nutzt das System ein eigenes Validierungsverfahren, dessen Logik in einer separaten Klassenstruktur organisiert wird. Während die `ParameterField`-Klasse für das #htl3r.short[html]-Element zuständig ist, übergibt sie die inhaltliche Prüfung an Datentyp-Klassen.

Auch hier wird ein modularer Ansatz verfolgt. Die abstrakte Basisklasse `Datatype` definiert die Methode `check(value)`, welche die Gültigkeit eines Wertes bestätigt. Klassen wie `IPv4` oder `CiscoInterface` implementieren diese Methode mit der jeweiligen Logik.

Der folgende Ausschnitt zeigt die Implementierung einer solchen Prüfung am Beispiel einer IPv4-Adresse:

#htl3r.code(
  caption: [Implementierung der Datentyp-Klasse IPv4],
  description: `ipv4.js`,
)[
  ```javascript
  class IPv4 extends Datatype {
    // Überprüft, ob der übergebene Wert eine IPv4-Adresse ist
    check(value) {
      const p = value.split('.');
      return p.length === 4 && p.every(n => n >= 0 && n <= 255);
    }
    getDescription() { return "An IPv4 address"; }
    toString() { return "ipv4"; }
    displayName() { return "IPv4"; }
  }
  ```
]

Diese Struktur ermöglicht eine einfache Überprüfung der Eingabe. Ein #htl3r.long[eventhandler] verbindet das Eingabefeld mit dem passenden Datentyp. Bei jeder Änderung des Werts wird die `check()`-Methode ausgeführt und das Ergebnis verarbeitet. Dies stellt sicher, dass der Benutzer nur dann einen Test erstellen kann, wenn alle Parameter den Vorgaben entsprechen.

== Abhängigkeitsmanagement
In komplexen Netzwerkszenarien sind Parameter meistens voneinander abhängig.
Oft bestimmt die Auswahl einer Option, ob weitere Eingaben nötig oder verboten sind. _#htl3r.long[diagnet]_ bildet diese Abhängigkeiten durch ein System ab, das auf Änderungen reagiert.

Das System unterscheidet dabei zwei Arten von Abhängigkeiten:

*Gegenseitiger Ausschluss*: Bestimmte Parameter dürfen nicht gleichzeitig gesetzt werden. Das System merkt sich Gruppen von solchen exklusiven Feldern. Sobald der Benutzer einen Wert in eines dieser Felder einträgt, werden alle anderen Felder der Gruppe automatisch deaktiviert und gesperrt. Erst wenn das Feld wieder geleert wird, gibt das System die anderen Optionen wieder frei.

*Bedingte Sichtbarkeit*: Manche Parameter sind nur relevant, wenn ein anderer Parameter einen bestimmten Wert hat. Hier fungieren Felder als Auslöser. Ändert sich der Wert eines solchen Auslösers, prüft das System die hinterlegten Bedingungen. Je nach Ergebnis werden die betroffenen Felder dynamisch eingeblendet oder versteckt. Da diese Logik direkt in der Klasse der Eingabefelder verankert ist, reagiert das Formular auf jede Benutzerinteraktion.

Um diese dynamischen Abläufe im Formular technisch umzusetzen, geht die nachfolgende Funktion alle verfügbaren Parameter Schritt für Schritt durch.
Für jedes Feld schaut das System in einem zentralen Verzeichnis nach, ob andere Eingaben von genau diesem Parameter abhängen.
Gibt es solche Verknüpfungen, erhält das auslösende Feld eine interne Benachrichtigungsfunktion.
Jedes Mal, wenn der Benutzer nun den Wert dieses Feldes anpasst, gibt diese Funktion die Änderung sofort an alle verknüpften Felder weiter.
Diese können dann in Echtzeit reagieren und sich passend einblenden oder sperren.

#htl3r.code(
  caption: [Implementierung der Update-Logik für abhängige Parameter],
  description: `choose_parameters.js`,
)[
  ```javascript
  function createActivationHandler(allParameters) {
    for (const parameter of allParameters) {
      const parameterName = parameter["name"];
      // Suche alle Felder, die von diesem Parameter abhängen
      const dependents = dependencyMap[parameterName];
      if (dependents) {
        // Funktion zur Aktualisierung abhängiger Felder erstellen
        parameter["activation_handler"] = async () => {
          dependents.forEach((item) => {
            // Neuberechnung der Sichtbarkeit für das abhängige Feld
            item.handleActivationTrigger(parameterName, parameter.getValue());
          });
        };
      }
    }
  }
  ```
]

== Zusammenführung und Erstellung
Den Abschluss bildet das Einsammeln der Benutzereingaben. Da das System die Gültigkeit der Daten bereits während der Eingabe überwacht, ist beim finalen Absenden keine erneute Prüfung notwendig. Sobald der Anwender die Erstellung bestätigt, geht der Algorithmus die Liste aller Parameter durch. Dabei greift er auf die `getValue()`-Methode der Felder zurück, um die eingetragenen Werte auszulesen. Die Daten werden in einem #htl3r.short[json]-Objekt gesammelt und über eine #htl3r.short[api]-Schnittstelle an das Backend übermittelt. Dieses nutzt die Informationen, um den Testfall zu erstellen und in der Datenbank zu speichern.

#htl3r.code(
  caption: [Erstellung des Testfalls im Backend],
  description: `views.py`,
)[
  ```python
  def create_test(request):
      data = json.loads(request.body)
      test_class = data.get("test_class")
      params = data.get("parameters", {})

      # Speicherung des Testfalls
      new_test = TestCase()
      new_test.test_module = test_class
      new_test.save()

      # Speicherung der Parameter
      for param_name, value in params.items():
          # Berücksichtigt auch Listen und Geräte
          store_test_parameter(new_test, param_name, value)

      return JsonResponse({"status": "success"}, status=201)
  ```
]
