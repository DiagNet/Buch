#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Luka Pacar")

= Routing Tests
Die Routing-Tests validieren die korrekte Weiterleitung von Netzwerkverkehr über alle Schichten der Netzwerktopologie hinweg.
Der Fokus liegt auf der Überprüfung der dynamischen Routing-Protokolle *#htl3r.full[rip]*, *#htl3r.full[eigrp]*, *#htl3r.full[ospf]* und *#htl3r.full[bgp]*.
Zusätzlich deckt das Framework Technologien für Redundanz und Sicherheit ab, darunter *#htl3r.full[hsrp]*, *#htl3r.full[glbp]*, *#htl3r.full[dmvpn]* und *#htl3r.full[ipsec]*.
Im Gegensatz zu einfachen Verbindungstests analysieren diese Module den operativen Zustand der Protokolle direkt auf den Geräten.
Das System vergleicht die Routing-Tabellen, Nachbarschaften und Interfaces mit den konfigurierten Soll-Werten.

== Datenbeschaffung
Die Test-Engine bezieht die notwendigen Informationen direkt aus der Ausgabe der Netzwerkgeräte.
Da diese Rückgaben aus unformatiertem Text bestehen, muss das Framework die relevanten Daten isolieren.
Hierfür kommen zwei unterschiedliche Verfahren zum Einsatz.
Die Wahl der Methode hängt davon ab, ob für den spezifischen Befehl eine Bibliothek zur Verarbeitung existiert.

=== Strukturierte Daten
Die bevorzugte Methode nutzt die Parser der Bibliothek #htl3r.long[pyats], welche die Text-Ausgabe der Konsole direkt in strukturierte Datenobjekte umwandelt.
Dadurch muss der Testcode den Text nicht manuell durchsuchen, sondern greift über definierte Namen auf die gewünschten Werte zu.
Dieses Verfahren macht die Testfälle unempfindlich gegenüber kleinen Formatänderungen in der Geräteantwort.

=== Rohdaten
Besitzen Befehle keinen Parser oder liefern keine strukturierten Daten, nutzt das System die Rohdatenausgabe der Konsole.
Hierfür kommen #htl3r.fullpl[regex] zum Einsatz, um die gesuchten Informationen aus dem unveränderten Text zu extrahieren.
Dieses Verfahren bietet zwar maximale Flexibilität für exotische Befehle, ist in der Implementierung jedoch deutlich aufwendiger, da der Entwickler das Antwortformat des Gerätes manuell interpretieren muss.

=== Parallele Ausführung
Da Tests für Protokolle wie #htl3r.short[ospf] oft viele Geräte gleichzeitig betreffen, würde eine nacheinander folgende Abfrage zu langen Wartezeiten führen.
Das Modul `OSPF_Areas` nutzt deshalb die in das #htl3r.long[pyats]-Framework integrierte Funktion `pcall` für asynchrone Aufrufe, wodurch die Abfrage auf allen Geräten zum gleichen Zeitpunkt startet.
Die Gesamtdauer des Tests hängt somit nur noch vom langsamsten Gerät ab und ist nicht mehr von der Anzahl der Router abhängig.

#htl3r.code(
  caption: [Parallele Datenabfrage mittels pcall],
  description: `OSPF_Areas.py`,
)[
  ```python
  # Die Funktion _fetch wird parallel für alle Geräte aufgerufen
  results = pcall(_fetch, device=device_list)

  # Zuordnung der Ergebnisse zu den Gerätenamen
  output = {dev.name: res for dev, res in zip(device_list, results)}
  ```
]

== Modellierung von Tabellen
Da Routing-Informationen wie Nachbarschaftslisten oder Routing-Tabellen eine variable Anzahl an Einträgen besitzen, ist die Modellierung der Parameter als tabellarische Struktur notwendig.
Eine einfache Definition von Einzelparametern würde die Flexibilität des Systems einschränken, da die Anzahl der prüfbaren Werte begrenzt wäre.
Durch den Einsatz des Datentyps `list` lassen sich beliebig viele Erwartungswerte in einem einzigen Testfall bündeln, was den administrativen Aufwand im Vergleich zu statischen Parametern erheblich reduziert.

Der folgende Codeausschnitt demonstriert die Definition einer solchen tabellarischen Struktur am Beispiel einer Routing-Tabelle:
#htl3r.code(
  caption: [Definition einer tabellarischen Parameterstruktur],
  description: `RoutingTable.py`,
)[
  ```python
  _params = [
      {
          "name": "routes",
          "type": "list",
          "parameters": [
              {"name": "network", "type": "IPv4-CIDR"},
              {"name": "next_hop", "type": "IPv4"},
              {"name": "metric", "type": "number"}
          ]
      }
  ]
  ```
]

== Implementierungsbeispiele
Die praktische Anwendung der Methoden zur Datenbeschaffung zeigt sich in drei unterschiedlichen Modulen, welche die theoretischen Konzepte in funktionalen Testcode umsetzen.

=== Routing Tabelle
Das Modul `RoutingTable` verifiziert die Einträge in der Routing-Tabelle des Gerätes, wobei es die strukturierte Datenverarbeitung über Parser nutzt.
Die Logik iteriert über die Liste der Soll-Routen und sucht die entsprechenden Netze in den abgerufenen Gerätedaten.
Durch diesen systematischen Abgleich stellt das Framework sicher, dass wichtige Netze über die korrekten Gateways sowie mit der geplanten Metrik erreichbar sind. Abweichungen werden für den Abschlussbericht gesammelt, um eine vollständige Analyse des Routing-Zustands zu ermöglichen.

#htl3r.code(
  caption: [Verarbeitung der Routing-Parameter],
  description: `RoutingTable.py`,
)[
  ```python
  # Abruf der strukturierten Daten
  config_output = self.device.get_genie_device_object().parse("show ip route")
  routes = config_output["vrf"]["default"]["address_family"]["ipv4"]["routes"]

  # Abgleich der Soll-Werte gegen die Gerätedaten
  for requirement in self.routes:
      target_net = requirement["network"]

      if target_net not in routes:
          failures.append(f"Route {target_net} not found")
          continue

      # Zusätzliche Prüfungen für Metrik und Next-Hop
  ```
]

=== GLBP
Im Gegensatz dazu überprüft das Modul #htl3r.short[glbp] die Redundanz von Gateways mithilfe der Rohdaten.
Da für diesen spezifischen Befehl kein Parser zur Verfügung steht, greift der Test auf #htl3r.longpl[regex] zum Filtern der Informationen zurück.
Ein Suchmuster extrahiert dabei den aktuellen Status der Redundanzgruppe aus dem Text der Konsole, damit der konfigurierte Wert gegen den erwarteten Zustand geprüft werden kann.


#htl3r.code(
  caption: [Extraktion des GLBP-Status mit #htl3r.short[regex]],
  description: `GLBP.py`,
)[
  ```python
  # Ausführen des Befehls und Erhalt der Textausgabe
  cmd = f"show glbp {group_id}"
  output = self.device.get_genie_device_object().execute(cmd)

  # Suche nach dem Status-Muster mittels regex
  match = re.search(r"State is (?P<state>\w+)", output)

  if match:
      actual_state = match.group("state")
      if actual_state != self.expected_state:
           failures.append(f"GLBP state mismatch")
  ```
]

=== BGP Nachbarschaften
Das Modul `BGP_Neighbors` stellt sicher, dass die Verbindungen zu den konfigurierten Nachbarn aktiv sind.
Da #htl3r.short[bgp] oft eine Vielzahl von Verbindungen umfasst, nutzt dieser Test ebenfalls die Listen-Verarbeitung.
Die Logik prüft für jeden definierten Nachbarn, ob der Status den Wert `Established` erreicht hat.

#htl3r.code(
  caption: [Validierung der BGP-Nachbarschaftsbeziehungen],
  description: `BGP_Neighbors.py`,
)[
  ```python
  # Abruf der BGP-Zustände
  bgp_data = self.device.get_genie_device_object().parse("show ip bgp summary")
  neighbors = bgp_data["vrf"]["default"]["neighbor"]

  # Prüfung der einzelnen Nachbarn aus der Parameter-Liste
  for peer in self.expected_peers:
      ip = peer["neighbor_ip"]

      if ip not in neighbors:
          failures.append(f"Neighbor {ip} not found in BGP summary")
          continue

      current_state = neighbors[ip].get("state")
      if current_state != "established":
          failures.append(f"Neighbor {ip} is in state {current_state}")
  ```
]
