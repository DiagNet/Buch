#import "@preview/htl3r-da:2.0.0" as htl3r

#pagebreak()

#htl3r.author("Karun Sandhu")
== CI/CD-Automatisierung <cicd_pipelines>

Dass #htl3r.long[diagnet] auf #htl3r.long[nix] als Fundament setzt, zahlt sich nicht nur lokal aus, sondern die gesamte Pipeline profitiert davon. Da die `flake.nix`-Datei alle Abhängigkeiten deklarativ fixiert, braucht ein frischer GitHub-Actions-Runner kein manuelles Setup: Ein einziger `nix`-Aufruf genügt, um dieselbe Umgebung zu reproduzieren, die auch auf dem Entwickler-Laptop läuft. Die Pipeline ist damit kein separates System, das gepflegt werden muss, sondern eine direkte Verlängerung der lokalen Entwicklungsumgebung.

Für die Versionierung verwendet #htl3r.long[diagnet] *ZeroVer* @zerover. Anders als Semantic Versioning signalisiert eine Version mit führender Null, z. B. `v0.3.1`, explizit, dass sich die Software noch in aktiver Entwicklung befindet und keine stabile #htl3r.short[api]-Stabilität garantiert wird. Für ein Schüler-Diplomprojekt ist das die ehrlichere Wahl: Die Software wird aktiv weiterentwickelt und ausgeliefert, ohne dabei Stabilitätsversprechen zu machen, die man zu diesem Zeitpunkt nicht halten kann.

=== GitHub Actions

GitHub Actions ist die in GitHub integrierte #htl3r.short[ci]/#htl3r.short[cd]-Plattform. Automatisierte Abläufe werden als *Workflows* in YAML-Dateien unter `.github/workflows/` definiert. Jeder Workflow besteht aus einem oder mehreren *Jobs*, die auf einem von GitHub bereitgestellten virtuellen Runner-Server ausgeführt werden. Ein Job wiederum setzt sich aus einzelnen *Steps* zusammen, von denen jeder entweder einen Shell-Befehl ausführt oder eine vorgefertigte *Action* aus dem GitHub Marketplace aufruft. Über den `on`-Schlüssel wird festgelegt, welche Ereignisse einen Workflow auslösen, z. B. ein Push auf einen bestimmten Branch, das Erstellen eines Tags oder ein Pull Request.

#pagebreak()

Ein minimales Beispiel verdeutlicht den Aufbau: Der folgende Workflow läuft bei jedem Push auf `main` und führt auf einem Ubuntu-Runner zwei Befehle aus.

#htl3r.code(
  caption: [Minimaler GitHub Actions Workflow zur Veranschaulichung der Struktur],
  description: `.github/workflows/example.yml`,
)[
  ```yaml
  on:
    push:
      branches: ["main"]

  jobs:
    beispiel-job:
      runs-on: ubuntu-latest
      steps:
        - name: Repository auschecken
          uses: actions/checkout@v6
        - name: Befehl ausführen
          run: echo "Hello from the runner"
  ```
]

`on` definiert den Trigger, `jobs` enthält die auszuführenden Jobs, und jeder Job besteht aus Steps, die entweder eine Action (`uses`) oder einen Shell-Befehl (`run`) ausführen. Actions sind vorgefertigte, wiederverwendbare Bausteine aus dem GitHub Marketplace, z. B. `actions/checkout`, das das Repository auf den Runner klont.

Die Pipelines von #htl3r.long[diagnet] lassen sich in drei funktionale Gruppen einteilen: Qualitätssicherung, Container-Build und Dokumentations-Build.

=== Gemeinsamer Nix-Workflow

Alle drei Gruppen teilen eine gemeinsame Basis: den wiederverwendbaren `nix.yml`-Workflow. GitHub Actions erlaubt es, Workflows über den Trigger `workflow_call` von anderen Workflows aufzurufen und dabei Parameter zu übergeben. `nix.yml` wird nie direkt durch ein Git-Ereignis ausgelöst, sondern nimmt ausschließlich solche Aufrufe entgegen. Er erwartet einen einzigen Parameter, nämlich den auszuführenden Shell-Befehl, installiert Nix auf dem Runner und richtet anschließend Cachix ein.

#pagebreak()

Cachix ist ein Binary-Cache-Dienst für den #htl3r.long[nix]-Store @nixos-homepage. Im #htl3r.long[nix]-Modell wird jede Abhängigkeit als sogenannte *Derivation* bezeichnet und durch einen kryptographischen Hash eindeutig identifiziert. Cachix speichert bereits gebaute Derivations und stellt sie über eine öffentliche URL bereit. Statt bei jedem Pipeline-Lauf alle Pakete neu zu kompilieren, prüft der Runner zuerst, ob eine Derivation mit dem passenden Hash bereits im Cache liegt, und lädt sie in diesem Fall direkt herunter. Dieser Cache ist auch in der `flake.nix`-Datei als `extra-substituters` eingetragen, sodass er lokal und in der Pipeline gleichermaßen greift:

#htl3r.code(
  caption: [Cachix-Konfiguration im gemeinsamen Nix-Basis-Workflow],
  description: `.github/workflows/nix.yml`,
)[
  ```yaml
  - uses: cachix/cachix-action@v16
    with:
      authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}
      extraPullNames: nix-community
      name: diagnet
  - run: ${{ inputs.command }}
    env:
      DIAGNET_DEBUG: False
      DIAGNET_SECRET_KEY: django-insecure-fallback-key-for-dev-only
      DIAGNET_DEVICE_ENCRYPTION_KEY: 8OGs8CTrNq8TltpMA3H-zybxADNlMt8FvdhEDo0QW98=
  ```
]

Der letzte Step führt den übergebenen Befehl aus und setzt dabei drei Umgebungsvariablen, die Django auch ohne laufende Datenbank benötigt: `DIAGNET_DEBUG` deaktiviert den Debug-Modus, `DIAGNET_SECRET_KEY` stellt einen Fallback-Schlüssel für kryptographische Operationen bereit, und `DIAGNET_DEVICE_ENCRYPTION_KEY` ist für die verschlüsselte Geräteverwaltung notwendig. Ohne diese Variablen würden `collectstatic` und die Testsuite bereits beim Import der Django-Settings scheitern. Der aufrufende Workflow übergibt nur den Befehl; alles andere, von der Nix-Installation bis zum Cache-Setup, erledigt die Basis. Das vermeidet Wiederholungen und stellt sicher, dass alle Workflows dieselbe Nix-Konfiguration verwenden.

#pagebreak()

=== Qualitätssicherung

Der `nix-ci.yml`-Workflow läuft bei jedem Pull Request und bei Merge-Group-Aktionen, also kurz bevor ein Branch in `main` gemergt wird. Er ruft den Basis-Workflow in zwei separaten Jobs auf: einmal mit #box(`nix flake check`) für statische Checks, einmal für die Tests.

#box(`nix flake check`) ist ein eingebauter Nix-Befehl, der alle in der `flake.nix`-Datei deklarierten Checks ausführt. Darunter fallen Formatierungsprüfung via #htl3r.long[treefmt], statische Analyse und Pre-Commit-Hooks. Schlägt auch nur einer davon fehl, blockiert der Check den Merge. Der zweite Job startet die Entwickler-Shell über #box(`nix develop`) und ruft darin die `just`-Rezepte auf:

#htl3r.code(
  caption: [Testausführung in der Nix-Entwicklungsumgebung],
  description: `.github/workflows/nix-ci.yml`,
)[
  ```yaml
  command: |
    nix develop --command just collectstatic
    nix develop --command just test
  ```
]

#box(`nix develop`) öffnet eine Shell mit der in der `flake.nix`-Datei definierten Entwicklungsumgebung, in der dann #box(`just collectstatic`) die statischen Dateien einsammelt und #box(`just test`) die Testsuite ausführt. Da diese Umgebung deterministisch aus derselben `flake.nix` aufgebaut wird wie lokal, ist sichergestellt, dass kein "works on my machine"-Problem auftreten kann.

=== Container-Build und Veröffentlichung

Der Container-Workflow gliedert sich in drei Jobs: `build`, `publish` und `release`. Sowohl `publish` als auch `release` hängen über `needs: build` direkt vom Build-Job ab und laufen nach dessen Abschluss parallel zueinander, wobei jeder nur unter einer bestimmten Bedingung aktiv wird.

#pagebreak()

Der Build-Job läuft bei jedem Pull Request, bei Pushes auf `main` und bei Version-Tags. Er ruft #box(`nix build .#container`) auf, das die in `nix/diagnet.nix` definierte `buildLayeredImage`-Derivation baut (siehe @containerization). Das Ergebnis landet als Symlink in `./result`. Da GitHub Actions keine Symlinks als Artefakte hochladen kann, wird der Symlink vor dem Upload dereferenziert:

#htl3r.code(
  caption: [Dereferenzierung des Nix-Symlinks vor dem Artefakt-Upload],
  description: `.github/workflows/container.yml`,
)[
  ```yaml
  - name: Build container with Nix
    run: nix build .#container
  - name: Dereference Nix symlink
    run: cp $(readlink result) diagnet-image.tar.gz
  ```
]

Das Tarball-Artefakt hat eine Aufbewahrungsdauer von einem Tag, da es nur als Zwischenspeicher zwischen den Jobs dient. Der `publish`-Job läuft ausschließlich bei Nicht-Pull-Requests. Er lädt das Tarball-Artefakt herunter, meldet sich an der GitHub Container Registry an und verwendet `docker/metadata-action`, um aus dem Git-Kontext automatisch passende Image-Tags zu generieren: Bei einem Push auf `main` wird das Image mit Branch-Name und Git-SHA getaggt. Wird ein Tag nach ZeroVer-Schema gesetzt, z. B. `v0.3.1`, generiert die Action zusätzlich `0.3.1`, `0.3` und `0`. Damit ist jede veröffentlichte Version über mehrere Tag-Granularitäten in der GitHub Container Registry abrufbar:

#htl3r.code(
  caption: [Automatische Image-Tag-Generierung nach ZeroVer-Schema],
  description: `.github/workflows/container.yml`,
)[
  ```yaml
  tags: |
    type=ref,event=branch
    type=semver,pattern={{version}}
    type=semver,pattern={{major}}.{{minor}}
    type=semver,pattern={{major}}
    type=sha
  ```
]

Der `release`-Job wird ausschließlich bei Tags ausgelöst, die dem Muster #box(`refs/tags/v`) entsprechen. Er lädt ebenfalls das Tarball-Artefakt herunter und legt über `softprops/action-gh-release` ein GitHub Release mit automatisch generierten Release-Notes an, an das das Container-Image direkt angehängt wird.

=== Dokumentations-Build

Parallel zum Applikations-Code wird auch das Diplomarbeitsbuch selbst automatisiert gebaut. Wie die anderen Workflows verwendet auch dieser Cachix, um bereits gebaute Derivations zwischenzuspeichern und den Nix-Store nicht bei jedem Lauf neu aufbauen zu müssen:

#htl3r.code(
  caption: [Build des Diplomarbeitsbuchs via Typix],
  description: `.github/workflows/build.yml`,
)[
  ```yaml
  - uses: cachix/cachix-action@v16
    with:
      authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}
      name: diagnet
  - name: Compile Book
    run: nix run .#build
  ```
]

#box(`nix run .#build`) ruft die in der `flake.nix`-Datei definierte Typix-Derivation auf, die Typst installiert und als PDF kompiliert. Diese wird als Artefakt hochgeladen und bei einem Tag-Release direkt an das GitHub Release angehängt.
