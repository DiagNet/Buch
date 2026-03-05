#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Luka Pacar")
= Die Test-Engine
Das Backend von DiagNet sorgt für die Ausführung, Auswertung und Steuerung der Netzwerktests. Um eine einheitliche und wartbare Testinfrastruktur zu gewährleisten, haben wir eine modulare Architektur entwickelt, die auf einer abstrakten Basisklasse basiert.
`DiagNetTest` bildet das Fundament für alle implementierten Tests und kapselt die gesamte Logik zur Testausführung, einschließlich Parameter-Validierung, Abhängigkeitsmanagement und Ergebnisverarbeitung.

#htl3r.code(
  caption: [Struktur der DiagNetTest-Klasse],
  description: `base.py`,
)[
  ```python
  class DiagNetTest:
      _params = []
      _mutually_exclusive_parameters = []

      def run(self):
          "Führt den Test mit den übergebenen Parametern aus"
          self.check_parameter_validity()
          self.discover_testcases()
          self.apply_decorators()
          self.execute_test()
          self.process_results()
  ```
]

Der Aufbau von `DiagNetTest` gliedert sich in drei wesentliche Komponenten: die Definition der Parameter, die Implementierung der Testmethoden sowie die Ausführung durch die `run()`-Methode.

== Definition der Parameter
Die Schnittstelle für Eingabedaten wird deklarativ über das Klassenattribut `_params` definiert. Dies ist eine Liste von Dictionaries, wobei jeder Eintrag einen spezifischen Eingabeparameter beschreibt. Die Definition unterscheidet hierbei zwischen Schlüsseln, die für die technische Verarbeitung zwingend notwendig sind, und solchen, die der Steuerung oder der Benutzerfreundlichkeit dienen.

=== Erforderliche Schlüsselwörter
Damit das Framework einen Parameter verarbeiten kann, muss die Definition mindestens zwei Attribute enthalten:

*`name`*:
Die technische Bezeichnung des Parameters.
Dieser String dient als interne Referenz und wird zur Laufzeit als Attributname der Testinstanz verwendet (z. B. `self.destination`).
Daher muss er zwingend die syntaktischen Merkmale einer validen Python-Variable aufweisen (keine Leerzeichen, keine Sonderzeichen, Start mit Buchstaben oder Underscore).

*`type`*:
Das Attribut type bestimmt das erwartete Datenformat und die Validierung im Frontend. Für die Implementierung der Testlogik ist jedoch die Art der Datenübergabe an Python entscheidend. Grundsätzlich reicht das Framework alle Parameter inklusive numerischer Werte und IP-Adressen als einfache Zeichenkette an den Test weiter. Eine manuelle Konvertierung ist daher bei Bedarf notwendig.

Das Backend implementiert jedoch drei zentrale Ausnahmen bei denen eine Validierung stattfindet:

- *`device`*: Parameter dieses Typs werden automatisch gegen die Bestandsdatenbank aufgelöst. Die Testmethode erhält statt eines Namens direkt die Objekt-Instanz des Gerätes als Django Model. Dies ermöglicht den direkten Zugriff auf verknüpfte Daten oder Methoden.

- *`choice`*: Dieser Typ repräsentiert ein Auswahlfeld, das den Parameter auf einen festen Wertebereich beschränkt. Die Definition erfordert zwingend den Schlüssel *`choices`*, in welchem die zulässigen Optionen als Liste hinterlegt werden müssen.
  Das Backend validiert zur Laufzeit strikt, ob der übergebene Wert in dieser Menge enthalten ist, und weist ungültige Eingaben ab.
- *`list`*: Dieser Typ dient als Container für wiederholbare Datenstrukturen und wird als native Python-Liste übergeben. Da jeder Listeneintrag wiederum aus mehreren eigenen Parametern bestehen kann, lassen sich damit auch komplexe Datensätze wie Tabellen abbilden

  Die Verwendung dieses Typs erfordert zwingend die Angabe des zusätzlichen Schlüssels *`parameters`*. Er definiert das Schema und somit die verschachtelten Parameter, denen alle Einträge der Liste entsprechen müssen.

#htl3r.code(
  caption: [Parameterstruktur mit deklarierten Datentypen],
)[
  ```python
  _params = [
          {
              "name": "bgp_peer",
              "type": "device"
          },
          {
              "name": "routes",
              "type": "list"
              "parameters":
              [
                  {
                      "name": "address_family",
                      "type": "choice",
                      "choices": ["IPv4", "IPv6"]
                  }
              ]
          },
      ]

  def test_example():
      self.bgp_peer.parse("show ip bgp") # Device Parameter
      for entry in self.routes: # List Parameter [Entry1, Entry2, ...]
          entry['address_family'] # Choice Parameter
  ```
]
=== Optionale Schlüsselwörter

Neben den zwingend erforderlichen Definitionen unterstützt das Parameterschema eine Reihe optionaler Attribute. Diese dienen einerseits dazu, die Benutzerfreundlichkeit im Frontend durch sprechende Labels und Hilfetexte zu optimieren, und andererseits, um komplexe Validierungslogiken und Abhängigkeiten zwischen verschiedenen Eingabefeldern abzubilden.

==== Präsentation und Frontend
Diese Attribute steuern ausschließlich die visuelle Darstellung der Parameter in der Benutzeroberfläche und haben keinen direkten Einfluss auf die interne Testlogik.

*`display_name`*: Definiert die Beschriftung des Eingabefeldes in der #htl3r.full[gui]. Fehlt dieser Schlüssel, greift das System automatisch auf den technischen Variablennamen zurück. Dies ermöglicht eine benutzerfreundliche Darstellung wie "BGP AS Number" bei gleichzeitiger Beibehaltung des technisch notwendigen Variablennamens bgp_as_number.

*`description`*: Ermöglicht die Hinterlegung eines ausführlichen Hilfetextes. Dieser wird dem Anwender im Frontend angezeigt und dient dazu, die Bedeutung des Parameters zu erläutern.

#htl3r.code(
  caption: [Definition der Frontend-Attribute],
)[
  ```python
  _params = [
      {
          "name": "target_as",
          "type": "positive-number",
          "displayName": "Remote AS Number",
          "description": "Die erwartete Autonomous System Number des Peers"
      },
  ]
  ```
]
==== Validierung und Steuerungslogik
Diese Attribute beeinflussen, ob und unter welchen Bedingungen ein Parameter vom Framework als obligatorisch betrachtet wird.

*`requirement`*: Steuert den generellen Pflichtstatus des Parameters. Standardmäßig gelten alle definierten Parameter als zwingend. Durch das Setzen dieses Wertes auf optional wird die Eingabe für den Anwender freiwillig. Leere optionale Felder werden dem Framework nicht übergeben.

*`required_if / forbidden_if`*: Erlaubt die Definition bedingter Abhängigkeiten zwischen Parametern. Diese Logik greift, wenn die Relevanz eines Feldes von der Eingabe eines anderen abhängt. Diese Attribute erwarten eine Referenz auf einen anderen Parameter und werten dessen Zustand zur Laufzeit aus, um den Validierungsstatus des aktuellen Feldes dynamisch anzupassen.
#htl3r.code(
  caption: [Anwendungsbeispiel für bedingte Abhängigkeiten],
)[
  ```python
  _params = [
      {
          "name": "address_family",
          "type": "choice",
          "choices": ["IPv4", "IPv6"],
          "requirement": "optional"
      },

      # relevant wenn address_family == IPv4
      {
          "name": "ipv4_network",
          "type": "IPv4-CIDR",
          "required_if": {"address_family": "IPv4"},
      }
  ]
  ```
]
=== Logische Ausschlüsse (Mutually Exclusive)
Einige Testszenarien erfordern Parameter, die sich logisch ausschließen (z. B. darf ein Ping-Test nicht gleichzeitig eine feste Anzahl an Paketen senden und unendlich laufen). Um solche Konflikte im Framework abzubilden, stellt die Basisklasse das Attribut *`mutually_exclusive_parameters`* bereit.

Hierbei handelt es sich um eine Liste von Parameter-Gruppen. Das Framework validiert vor jeder Ausführung, dass innerhalb einer solchen Gruppe niemals mehrere Parameter gleichzeitig gesetzt sind.

Die Validierungslogik unterscheidet dabei automatisch zwischen optionalen und verpflichtenden Parametern:

*Optionale Gruppen*: Sind alle Parameter einer Gruppe optional, darf der Nutzer maximal einen oder gar keinen davon setzen.

*Verpflichtende Gruppen*: Sind die Parameter als required definiert, erzwingt das Framework, dass exakt einer aus der Gruppe gesetzt wird.

#htl3r.code(
  caption: [Definition sich gegenseitig ausschließender Parameter],
)[
  ```python
  _params = [
          {"name": "count", "type": "int", "requirement": "optional"},
          {"name": "duration", "type": "int", "requirement": "optional"},
          {"name": "target", "type": "str"}
      ]

  # Definition der Gruppe
  _mutually_exclusive_parameters = [
      ["count", "duration"]
  ]
  ```
]
In diesem Szenario unterbindet das Framework die gleichzeitige Übergabe von *`count`* und *`duration`*. Somit wird der Testablauf entweder durch die Paketanzahl oder die Zeitdauer begrenzt.


== Implementierung der Testmethoden
Die eigentliche Testlogik wird innerhalb der Testklasse in dedizierten Methoden implementiert. Das Framework folgt hierbei einem strikten Namensschema , um Testfälle automatisch zu identifizieren und von internen Hilfsfunktionen zu unterscheiden.

Jede Methode, die als eigenständiger Testfall ausgeführt werden soll, muss zwingend mit dem Präfix *`test_`* beginnen. Methoden ohne dieses Präfix werden vom Discovery-Prozess ignoriert und können als Helper-Methoden genutzt werden.

=== Rückgabewerte
Ein Test gilt als erfolgreich, wenn die Methode entweder `True`, `None` oder einen informativen Text zurückgibt. Letzterer wird vom Framework automatisch als Erfolgsmeldung in das Protokoll übernommen. Als fehlgeschlagen wird ein Test gewertet, wenn er explizit `False` zurückgibt oder während der Ausführung eine `Exception` auftritt. Diese wird abgefangen und die angegebene Fehlermeldung wird dem Framework übergeben.


#htl3r.code(
  caption: [Beispiele für Erfolgs- und Fehlerzustände],
)[
  ```python
  def test_device_reachability(self):
      # Ergebnis wird durch True/False entschieden - Keine Nachricht
      return self.device.is_reachable()

  def test_gateway_reachability(self):
      # Ergebnis ist ein String - PASS mit Erfolgsnachricht
      return "gateway is reachable"

  def test_fetch_data(self):
      # Ergebnis ist eine Exception - FAIL mit Protokollnachricht
      raise ValueError("unable to fetch data")
  ```
]

=== Steuerung mittels Dekoratoren
Um das Verhalten einzelner Testmethoden zu modifizieren, ohne den eigentlichen Testcode mit Verwaltungslogik zu vermischen, setzt DiagNet auf Python-Dekoratoren. Diese ermöglichen eine praktische Steuerung, bei der Eigenschaften wie Wiederholungen oder Ausführungsbedingungen direkt an der Methodendefinition annotiert werden. Diese Metadaten werden vom Framework vor der Ausführung evaluiert.

#htl3r.code(
  caption: [Anwendungsbeispiele für die verfügbaren Dekoratoren],
)[
  ```python
  # Wiederholt den Test 3-mal mit 1 Sekunde Verzögerung
  @repeat(times=3, delay=1)
  def test_stability(self):
      return self.device.ping()

  # Markiert Tests, die aufgrund fehlender Features übersprungen werden sollen
  @skip("Feature noch nicht implementiert")
  def test_future_feature(self):
      pass

  # Erwartet einen Fehlschlag (z.B. Testen von Negativ-Szenarien)
  @expected_failure
  def test_security_violation(self):
      # Gibt False zurück, wird dann aber als PASS gewertet
      return False
  ```
]

=== Definition von Abhängigkeiten
Innerhalb komplexer Testabläufe bestehen oft logische Kausalitäten zwischen verschiedenen Prüfungen. Eine detaillierte Protokoll-Analyse ist beispielsweise obsolet, sofern bereits die grundlegende Erreichbarkeit des Gerätes gescheitert ist. Um kaskadierende Fehlermeldungen zu vermeiden und die Ausführungszeit zu optimieren, stellt das Framework den Dekorator *\@depends_on* bereit.

Dieser markiert eine Testmethode als abhängig von einem spezifischen Vorgänger. Die Referenzierung erfolgt hierbei über den Methodennamen als Text. Das Framework stellt sicher, dass der abhängige Test erst nach dem erfolgreichen Abschluss der referenzierten Methode ausgeführt wird. Sollte die Vorbedingung scheitern oder selbst übersprungen werden, entfällt die Ausführung des abhängigen Tests und dieser erhält im Protokoll automatisch den Status SKIPPED.

#htl3r.code(
  caption: [Anwendungsbeispiele für die verfügbaren Dekoratoren],
)[
  ```python
  def test_reachability(self):
      if not self.device.is_reachable():
          return False
      return True

  @depends_on("test_reachability")
  def test_routing_table(self):
      # Wird nur ausgeführt, wenn test_basic_reachability erfolgreich war.
      # Andernfalls wird dieser Test übersprungen.
      return self.device.parse("show ip route")
  ```
]

== Komponenten der `run()`-Methode
Die Methode `run()` ist der zentrale Einstiegspunkt für die Testausführung.
Sie steuert den gesamten Testablauf zentral und stellt sicher, dass alle Voraussetzungen validiert sind, bevor die eigentliche Ausführung beginnt. Der Ablauf gliedert sich dabei in folgende Phasen:

=== Parameter-Validierung
Überprüft, ob alle _erforderlichen_ Parameter vorhanden sind, und ob keine _mutually exclusive_ Parameter gleichzeitig gesetzt wurden. Gültige Parameter werden dynamisch als #htl3r.long[instanzattribute] zugewiesen, sodass in den Testmethoden über *`self.parameter_name`* direkt auf sie zugegriffen werden kann.

#htl3r.code(
  caption: [Zugriff auf einen Parameter],
)[
  ```python
  # Definiert die Parameter für den Testfall
  _params = [
      {
          "name": "bgp_peer", # Name
          "type": "device"    # Datentyp
      }
  ]

  @repeat(2)
  def test_bgp(self):
      # Greift auf den Parameter als Instanzattribut zu
      self.bgp_peer.connect()
      # ...
      return True
  ```
]

=== Dynamisches Test-Discovery
Mittels Introspektion durchsucht das Framework die Klasse zur Laufzeit nach Methoden, die dem Namensschema *`test_`* entsprechen. Diese Methoden werden als einzelne Testmodule interpretiert.

#htl3r.code(
  caption: [Filter nach Testmodulen],
  description: `base.py`,
)[
  ```python
  for attr in dir(self): # Durchsucht alle Attribute der Instanz
      if attr.startswith("test_"): # Filtert nach "test_"
          method = getattr(self, attr)
          if callable(method): # Akzeptiert nur aufrufbare Methoden
              test_methods.append((attr, method))
  ```
]

=== Abhängigkeitsmanagement
Innerhalb einer Testklasse bauen Prüfungen oft logisch aufeinander auf. DiagNet erlaubt die Definition solcher Kausalitäten mittels des *`@depends_on`* Dekorators.
Die `run()`-Methode analysiert diese Beziehungen und erstellt mittels topologischer Sortierung einen validen Ausführungsplan.

==== Kahn's Algorithmus
Um die definierten Abhängigkeiten in eine linear ausführbare Sequenz zu überführen, nutzt die `run()`-Methode eine Implementierung des Algorithmus von Kahn. Dieser Ansatz interpretiert die Testmethoden und ihre Beziehungen als gerichteten Graphen und ermöglicht eine Topologische Sortierung.
#figure(
  image("../assets/gerichteter_graph.png", width: 60%),
  caption: [Beispielhafte Darstellung eines gerichteten Graphen (Quelle: Wikipedia)],
) <fig-kahn>

Der Algorithmus gliedert sich in vier Phasen:

*Graphen-Konstruktion*:
Zunächst iteriert das System über alle aktiven Testmethoden und baut eine #htl3r.long[adjazenzliste] auf. Parallel dazu wird jedem Test ein Zählerwert zugewiesen, der exakt beziffert, von wie vielen anderen Tests er direkt abhängig ist.

#htl3r.code(
  caption: [Aufbau des Graphen und Berechnung der Eingangsgrade],
  description: `base.py`,
)[
  ```python
      for name, func in test_methods:
          dep = getattr(func, "_depends_on", None)
          if dep: # Gibt es eine Beziehung für diesen Testcase?
              graph[dep].append(name) # Adjazenz in den Graphen eintragen
              in_degree[name] += 1 # Erhöht die Anzahl an Abhängigkeiten

  ```
]
*Initialisierung der Warteschlange:*
Alle Tests die keine Abhängigkeiten besitzen, werden in eine Warteschlange eingereiht. Da für diese Elemente keine Vorbedingungen erfüllt werden müssen, bilden sie die Startmenge der ausführbaren Tests.
#htl3r.code(
  caption: [Initialisierung der Warteschlange mit unabhängigen Knoten],
  description: `base.py`,
)[
  ```python
  # Alle Methoden ohne Eingangskanten kommen in die Warteschlange
  queue = deque([n for n in all_methods if in_degree[n] == 0])
  ```
]
*Auflösung der Abhängigkeiten:*
Das System arbeitet die Warteschlange Schritt für Schritt ab. Jeder entnommene Test wird fest eingeplant und gilt damit als „erledigt“. Dies reduziert bei allen nachfolgenden Tests, die auf ihn gewartet haben, den Abhängigkeitszähler. Fällt der Zähler eines Tests dabei auf Null, sind seine Voraussetzungen erfüllt: Er wird freigeschaltet und reiht sich ebenfalls in die Warteschlange ein.

#htl3r.code(
  caption: [Iterative Abarbeitung und Auflösung der Abhängigkeiten],
  description: `base.py`,
)[
  ```python
  while queue:
      node = queue.popleft()
      result.append(node) # Test final einplanen

      for neighbor in graph[node]:
          in_degree[neighbor] -= 1 # Vorbedingung für Nachfolger erfüllen
          if in_degree[neighbor] == 0:
              queue.append(neighbor) # Nachfolger wird eingereiht
  ```
]

*Erkennung von Endlosschleifen:*
Nachdem die Warteschlange abgearbeitet ist, prüft das System, ob noch Verbindungen bestehen. Wenn der Algorithmus endet, aber die Anzahl der eingeplanten Tests kleiner ist als die Gesamtmenge, bedeutet dies, dass die verbleibenden Tests noch auf unerfüllte Abhängigkeiten warten. Da diese Situation in einem endlichen Graphen nur durch eine Schleife entstehen kann, bricht das Framework den Vorgang mit einer Fehlermeldung ab.

#htl3r.code(
  caption: [Validierung auf zyklische Abhängigkeiten],
  description: `base.py`,
)[
  ```python
  if len(result) != len(all_methods):
      raise DependencyException("Cycle detected in test dependencies")
  ```
]

Das Ergebnis des Algorithmus ist eine Liste, die alle Testmethoden in ihrer topologisch korrekten Reihenfolge enthält

#figure(
  image("../assets/solved_topological_sort.png", width: 60%),
  caption: [Resultat einer topologischen Sortierung nach Kahn (Quelle: Wikipedia)],
) <fig-kahn-result>

Die run()-Methode verwendet diese Liste anschließend als Ausführungsplan. Sie iteriert über die Einträge und führt die Tests nacheinander aus, mit der Gewissheit, dass zum Zeitpunkt der Ausführung eines Tests alle seine notwendigen Vorbedingungen bereits bearbeitet wurden.

=== Ausführung und Resultate der Testfälle
Vor dem eigentlichen Aufruf der Testfunktionen evaluiert das Framework die hinterlegten Dekoratoren und modifiziert den Ablauf entsprechend. Dies stellt sicher, dass Abfolgen wie Wiederholungen oder Ausschlüsse technisch abgearbeitet werden, noch bevor der erste Testfall ausgeführt wird.

Nach Abschluss aller Testfälle aggregiert das Framework die Einzelresultate in einem universellen Ergebnisobjekt. Dieses Dictionary dient als standardisierte Schnittstelle für das Frontend und beinhaltet neben dem Gesamtstatus eine statistische Zusammenfassung sowie die detaillierten Laufzeitdaten jedes Tests.

#htl3r.code(
  caption: [Struktur des aggregierten Ergebnisobjekts],
)[
  ```python
  {
      "result": "FAIL", # Gesamtstatus (PASS nur bei 0 Fehlern)
      "summary": (3, 1, 1, 1), # (Total, Pass, Fail, Skipped)
      "tests": {
          "test_reachability": {
              "status": "PASS",
              "message": "Connection established",
              "time": 3.045
          },
          "test_auth": {
              "status": "FAIL",
              "message": "Authentication failed",
              "time": 0.12
          },
          "test_config": {
              "status": "SKIPPED",
              "message": "Skipped due to failed dependency: test_auth",
              "time": 0
          }
      }
  }
  ```
]
