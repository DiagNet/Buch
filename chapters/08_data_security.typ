#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Karun Sandhu")
== Datenmodellierung und Datensicherheit <data_security>

Eine Webanwendung ist letztlich nur so zuverlässig wie das Datenbankschema, auf dem sie aufbaut. Für #htl3r.long[diagnet] bedeutete das, zwei unterschiedliche Anforderungen unter einen Hut zu bringen: Einerseits mussten die Datenstrukturen flexibel genug sein, um sehr unterschiedliche Netzwerktests mit ihren jeweiligen Parametern abzubilden. Andererseits durfte diese Flexibilität nicht auf Kosten der Datenintegrität gehen, da fehlerhafte Konfigurationen in einem Netzwerktestsystem direkt zu falschen Testergebnissen führen können.

Eng damit verknüpft ist die Frage der Datensicherheit: Zugangsdaten für Netzwerkgeräte zählen zu den sensibelsten Informationen einer IT-Infrastruktur und müssen entsprechend geschützt werden. Dieses Kapitel beschreibt die Konzeption des Datenbankschemas und die Maßnahmen zum Schutz dieser Daten vor unbefugtem Zugriff. Da das Schema in seiner Gesamtheit zu komplex für eine einzelne Abbildung wäre, zeigen @erd_struktur und @erd_ausfuehrung jeweils eine vereinfachte Sicht, die auf die für das Verständnis wesentlichen Felder und Relationen reduziert wurde.

#figure(
  image("../assets/erd_struktur.png", width: 100%),
  caption: [Datenbankschema: Geräteverwaltung und Teststruktur],
) <erd_struktur>

#figure(
  image("../assets/erd_ausfuehrung.png", width: 100%),
  caption: [Datenbankschema: Testausführung und Gruppierung],
) <erd_ausfuehrung>

=== Entity-Relationship-Modell und konzeptionelle Grundlagen

Bevor die konkrete Implementierung der Django-Modelle in Angriff genommen wurde, war eine sorgfältige Analyse der fachlichen Anforderungen notwendig. Ziel der Datenmodellierung war es, die realen Entitäten des Netzwerktestbetriebs (Geräte, Testfälle, deren Parameter sowie die historischen Ergebnisse) in ein konsistentes, normalisiertes relationales Schema zu überführen. Als Designgrundlage dient die #htl3r.full[3nf], um Redundanzen zu minimieren und die referenzielle Integrität der Daten zu wahren.

Das resultierende Datenmodell gliedert sich in vier Bereiche. Die *Geräteverwaltung* bildet physische und virtuelle Netzwerkgeräte samt ihren Verbindungsparametern ab. Die *Testfall-Domäne* beschreibt die abstrakten Testvorlagen inklusive des Python-Modulnamens für den dynamischen Classloader. Die *Parametrisierung* bildet die zur Laufzeit übergebenen Argumente in einer rekursiven Baumstruktur ab, da Netzwerktests sehr unterschiedliche Eingaben erfordern können. Abgeschlossene Testläufe werden schließlich in der *Ergebnisdomäne* unveränderlich gespeichert, damit jeder Zustandswechsel der Infrastruktur nachvollziehbar bleibt.

=== Das Device-Modell: Integrität auf Feldebene

Das Modell `Device` ist das Fundament der Anwendung, da nahezu jede andere Entität eine Beziehung zu einem Gerät aufweist. Aus diesem Grund wurden die Validierungsregeln direkt auf Datenbankebene an dieses Modell gebunden, um fehlerhafte Eingaben so früh wie möglich im Datenfluss abzufangen.

Für das Feld `ip_address` kommt Djangos natives `GenericIPAddressField` zum Einsatz. Dieser Feldtyp erzwingt auf Datenbankebene, dass ausschließlich syntaktisch korrekte #htl3r.short[ipv4]- oder #htl3r.short[ipv6]-Adressen persistiert werden können. Der Port wird als `IntegerField` mit den Validatoren `MinValueValidator(1)` und `MaxValueValidator(65535)` abgesichert, was dem durch #htl3r.short[tcp]/#htl3r.short[udp] definierten gültigen Portbereich entspricht. Für das Verbindungsprotokoll wurde ein `CharField` mit einer `choices`-Enumeration gewählt, sodass ausschließlich die definierten Werte `ssh` und `telnet` akzeptiert werden. Das Feld `device_type` unterscheidet zwischen sechs Geräteklassen, die jeweils Router- und Switch-Varianten der Betriebssysteme IOS, IOSXE und IOSXR abdecken.

Die kritischste Integritätsregel wird jedoch durch einen `CheckConstraint` in der inneren `Meta`-Klasse des Modells durchgesetzt. Da das unverschlüsselte #htl3r.long[telnet]-Protokoll ein inakzeptables Sicherheitsrisiko darstellt, wird dessen Verwendung in Kombination mit IOSXE-Geräten auf Datenbankebene hart unterbunden. Der Constraint greift dabei auf einen Suffix-Vergleich zurück (`device_type__endswith="iosxe"`), da sowohl Router als auch Switches unter IOSXE fallen:

#htl3r.code(
  caption: [Protokoll-Constraint zur Verhinderung von Telnet auf IOSXE-Geräten],
  description: `devices/models.py`,
)[
  ```python
  class Device(models.Model):
      PROTOCOLS = [
          ("ssh", "SSH"),
          ("telnet", "Telnet"),
      ]
      DEVICE_TYPES = [
          ("router_ios", "Router (IOS)"),
          ("router_iosxe", "Router (IOSXE)"),
          ("router_iosxr", "Router (IOSXR)"),
          ("switch_ios", "Switch (IOS)"),
          ("switch_iosxe", "Switch (IOSXE)"),
          ("switch_iosxr", "Switch (IOSXR)"),
      ]

      name = models.CharField("Hostname", max_length=100, unique=True)
      ip_address = models.GenericIPAddressField("IP Address")
      port = models.IntegerField(
          default=22,
          validators=[MinValueValidator(1), MaxValueValidator(65535)]
      )
      protocol = models.CharField("Protocol", choices=PROTOCOLS, default="ssh")
      device_type = models.CharField("Device Type", max_length=20, choices=DEVICE_TYPES)

      class Meta:
          constraints = [
              models.CheckConstraint(
                  condition=~(Q(protocol="telnet") & Q(device_type__endswith="iosxe")),
                  name="no_telnet_on_iosxe",
                  violation_error_message="Telnet is not allowed for IOSXE devices.",
              )
          ]
  ```
]

Dieser Ansatz ist der alternativen Implementierung einer Validierung in der View oder im Formular vorzuziehen. Ein Constraint auf Datenbankebene greift unabhängig davon, über welchen Pfad Daten eingespielt werden, ob über die Web-Oberfläche, die #htl3r.short[api] oder direkt per Datenbankzugriff.

=== Das TestCase-Modell: Dynamisches Laden via Reflection

Das Modell `TestCase` repräsentiert eine abstrakte Testvorlage. Sein zentrales Feld `test_module` speichert den Namen der Python-Klasse, die die eigentliche Testlogik implementiert. Die Test-Engine lädt diese Klasse zur Laufzeit dynamisch, was einem Reflection-Muster entspricht. Damit dieser Mechanismus fehlerfrei funktioniert, muss der gespeicherte Name zwingend der PascalCase-Namenskonvention von Python entsprechen. Diese Anforderung wird durch einen `RegexValidator` direkt am Datenbankfeld erzwungen, wie bereits im vorangegangenen Kapitel @django_framework beschrieben. Dieser verhindert, dass ein Netzwerkadministrator einen Modulnamen hinterlegt, der beim dynamischen Laden zu einem `ImportError` führen würde, ohne dass dies beim Speichern explizit kommuniziert wird.

Die Zuordnung eines Testfalls zu den Geräten, auf denen er ausgeführt werden soll, erfolgt nicht über ein direktes `ManyToManyField`, sondern über das separate Modell `TestDevice`. Dieses hält je einen `ForeignKey` auf `TestCase` sowie auf `Device` und ermöglicht so, einem Testfall beliebig viele Geräte zuzuordnen, ohne dass die Gerätekonfiguration dupliziert werden muss. Die Trennung in ein eigenständiges Modell bietet den Vorteil, dass pro Zuordnung zusätzliche Metadaten gespeichert werden könnten, ohne das `TestCase`-Modell selbst zu erweitern.

=== Parametrisierung: Rekursive Baumstruktur

Eine besondere Herausforderung bei der Datenmodellierung stellte die Abbildung der Testparameter dar. Netzwerktests sind in ihrer Parametrisierung sehr heterogen: Ein einfacher Ping-Test benötigt lediglich eine Zieladresse, während ein Routing-Test eine vollständige Liste von Präfixen, zugehörigen Next-Hops und weiteren Metadaten erwartet.

Um diese beliebig tief verschachtelten Strukturen in einem flachen relationalen Datenbankschema abzubilden, wurde das Modell `TestParameter` mit einer reflexiven Many-to-One-Beziehung versehen. Ein `TestParameter`-Datensatz kann über das Feld `parent_test_parameter` auf einen anderen `TestParameter` desselben Typs verweisen, womit er in der Hierarchie eine Kindposition einnimmt. Diese Technik, bekannt als *Adjacency List*, ist ein etabliertes Entwurfsmuster für die Speicherung von Baumstrukturen in relationalen Datenbanken. Sowohl `name` als auch `value` sind als `TextField` ohne Längenbegrenzung deklariert, da die maximale Länge eines Parameterwerts nicht vorhersehbar ist:

#htl3r.code(
  caption: [Reflexive Selbstreferenz des TestParameter-Modells],
  description: `networktests/models.py`,
)[
  ```python
  class TestParameter(models.Model):
      name = models.TextField()
      value = models.TextField(blank=True, null=True)
      test_case = models.ForeignKey(
          TestCase,
          on_delete=models.CASCADE,
          related_name="parameters",
          null=True,
          blank=True,
      )
      parent_test_parameter = models.ForeignKey(
          "self",
          on_delete=models.CASCADE,
          related_name="parent_parameter",
          null=True,
          blank=True,
      )
  ```
]

Zum Zeitpunkt der Testausführung muss diese Datenbankstruktur in ein maschinenlesbares #htl3r.short[json]-Objekt umgewandelt werden, das die Test-Engine als Eingabe erwartet. Hierfür implementiert das `TestCase`-Modell die Methode `getListParameter()`, die die Baumstruktur rekursiv traversiert. Trifft die Methode auf einen Parameter, dessen `value` auf den Sentinel-Wert `"list"` gesetzt ist, ruft sie sich selbst mit dem entsprechenden Kind-Knoten auf, anstatt dessen Wert direkt zu verwenden. Device-Parameter werden dabei über den separaten `related_name` `device_parent_parameter` aufgelöst und als Django-Modell-Instanzen eingebettet. Das Ergebnis ist eine korrekt verschachtelte Python-Liste im Format, das die Test-Engine als #htl3r.short[json]-Eingabe erwartet.

=== Die TestGroup: Batch-Ausführung durch ManyToMany

Um Netzwerkadministratoren die Möglichkeit zu geben, eine ganze Batterie von Tests mit einem einzigen Aufruf zu starten, wurde die Entität `TestGroup` eingeführt. Das Modell besitzt eine `ManyToManyField`-Beziehung zu `TestCase` und bündelt damit eine beliebige Sammlung von Testfällen.

#htl3r.code(
  caption: [Gruppierung von Testfällen via ManyToMany-Relation],
  description: `testgroups/models.py`,
)[
  ```python
  class TestGroup(models.Model):
      name = models.CharField(max_length=50, unique=True)
      testcases = models.ManyToManyField(TestCase)
  ```
]

In der relationalen Datenbank wird diese Beziehung durch eine automatisch von Djangos #htl3r.short[orm] verwaltete Zwischentabelle realisiert, die nur die Fremdschlüssel beider Entitäten hält. Das bedeutet, dass derselbe `TestCase` in mehreren `TestGroup`-Instanzen referenziert werden kann, ohne dass dessen Konfiguration dupliziert werden muss. Ändert ein Administrator die Parameter eines Testfalls, so profitieren automatisch alle Gruppen, die diesen Testfall enthalten, von der aktualisierten Definition.

=== Persistierung von Testergebnissen

Nach Abschluss eines Testlaufs speichert #htl3r.long[diagnet] das vollständige Ergebnis im Modell `TestResult`. Das Modell hält dabei zwei getrennte Zeitstempelfelder: `started_at` und `finished_at`, womit die Laufzeit eines Tests präzise nachvollziehbar bleibt. Das boolesche Feld `result` speichert, ob der Test bestanden wurde. Die eigentlichen Rohlogs und der strukturierte Statusbericht der Test-Engine werden im separaten `JSONField` `log` abgelegt, das direkt über Python-Dictionary-Syntax abfragbar ist, ohne vorher als Rohtext geparst werden zu müssen.

Die `save()`-Überschreibung folgt dem Prinzip des *Fat Model, Thin View*: Logik, die unabhängig vom Aufrufpfad korrekt laufen muss, gehört ins Modell und nicht in die View. Beim erstmaligen Speichern eines neuen `TestResult`-Datensatzes ermittelt die Methode den höchsten bereits vergebenen `attempt_id`-Wert für den entsprechenden `TestCase` und setzt den neuen Wert auf das nächste Inkrement:

#htl3r.code(
  caption: [Automatische Vergabe der attempt\_id beim Speichern eines Testergebnisses],
  description: `networktests/models.py`,
)[
  ```python
  class TestResult(models.Model):
      test_case = models.ForeignKey(
          TestCase, on_delete=models.CASCADE, related_name="results"
      )
      attempt_id = models.IntegerField(null=True, blank=True)
      started_at = models.DateTimeField()
      finished_at = models.DateTimeField(blank=True, null=True)
      result = models.BooleanField()
      log = models.JSONField(blank=True, null=True)

      class Meta:
          unique_together = ("attempt_id", "test_case")

      def save(self, *args, **kwargs):
          if self.attempt_id is None:
              last = (
                  TestResult.objects.filter(test_case=self.test_case)
                  .order_by("-attempt_id")
                  .first()
              )
              self.attempt_id = (last.attempt_id + 1) if last else 1
          super().save(*args, **kwargs)
  ```
]

Die `save()`-Implementierung ist dabei bewusst defensiv gestaltet: Statt alle vorhandenen Einträge zu zählen, wird der höchste bestehende `attempt_id`-Wert über `.order_by("-attempt_id").first()` ermittelt. Dieser Ansatz ist robuster, da er auch dann korrekt funktioniert, wenn zwischenzeitlich einzelne Ergebnisse gelöscht wurden. Das Constraint `unique_together` auf `(attempt_id, test_case)` sichert auf Datenbankebene zusätzlich ab, dass keine zwei Ergebnisse dieselbe Versuchsnummer für denselben Testfall erhalten können.

=== Datenbankmigrationen als versioniertes Schema

Jede Änderung an einem Django-Modell, sei es das Hinzufügen eines Feldes, die Modifikation eines Constraints oder die Einführung einer neuen Relation, wird durch das Migrationssystem des #htl3r.long[framework] als eigenständige, versionierte Migrationsdatei im Verzeichnis `migrations/` abgelegt. Diese Dateien sind Python-Skripte, die die Zustandsveränderung des Datenbankschemas atomar und reproduzierbar beschreiben.

Für den Produktionseinsatz von #htl3r.long[diagnet] hat dieses Vorgehen einen entscheidenden Vorteil: Das Datenbankschema kann von einem leeren Zustand aus durch den Befehl `python manage.py migrate` vollständig aufgebaut werden, ohne dass manuelle #htl3r.short[sql]-Skripte notwendig wären. Die Migrationsdateien selbst werden im Git-Repository versioniert und bieten damit eine nachvollziehbare Historie aller Schemaänderungen über die gesamte Projektlaufzeit.
