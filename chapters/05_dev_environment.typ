#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Karun Sandhu")
= Development & Environment <dev_env>
Durch die steigende Komplexität moderner Softwareprojekte werden stabile, reproduzierbare und isolierte Entwicklungsumgebungen immer wichtiger. Eines der wichtigsten Probleme, die es zu beseitigen gilt, ist die Diskrepanz zwischen der lokalen Umgebung der Entwickler und der Produktionsumgebung. Dies beschreibt das weit verbreitete "It works on my machine"-Problem @jetbrains-config-drift. Damit derartige Probleme nicht auftreten können, wurde in unserer Diplomarbeit ein neuer, deklarativer Ansatz gewählt, mit dem sichergestellt wird, dass alle Abhängigkeiten exakt definiert und versioniert sind.

== Reproduzierbarkeit durch Nix
Das Fundament bildet der Paketmanager #htl3r.long[nix]. Im Gegensatz zu herkömmlichen, imperativen Paketmanagern, die globale Zustände im Betriebssystem verändern, isoliert #htl3r.long[nix] jede Abhängigkeit in einem eigenen, unveränderlichen Pfad im sogenannten _#htl3r.long[nix] Store_ (z. B. `/nix/store/bfs3...-python-3.13`). Dieser Ansatz basiert auf dem funktionalen Deployment-Modell, bei dem Softwarekomponenten als unveränderliche Werte betrachtet werden @dolstra-nix. Dies verhindert Konflikte zwischen verschiedenen Versionen derselben Bibliothek und garantiert, dass die Entwicklungsumgebung auf jedem Rechner identisch ist @nixos-homepage.

=== Nix Flakes
Um die Versionierung der Abhängigkeiten zu fixieren, verwenden wir #htl3r.long[nix-flakes]. Diese Erweiterung des #htl3r.long[nix]-Ökosystems ermöglicht eine #htl3r.long[hermetic]e Abriegelung der Umgebung.

Zentral sind dabei zwei Dateien im Repository:
- `flake.nix`: Diese Datei definiert die *Inputs* (z. B. Paketquellen wie `nixpkgs`) und die *Outputs* (z. B. die Entwicklungsumgebung `devShell`). Sie beschreibt deklarativ, welche Tools benötigt werden.
- `flake.lock`: Ähnlich wie bei `package-lock.json` in JavaScript, "pinnt" diese Datei die exakten Hash-Werte aller verwendeten Pakete.

Nachfolgend ein stark vereinfachter Auszug aus unserer Konfiguration, der dennoch zeigt, wie Python und externe Tools einer #htl3r.long[nix-shell] hinzugefügt werden:

#htl3r.code(
  caption: [Eine vereinfachte `flake.nix`-Datei],
  description: `flake.nix`,
)[
  ```nix
  {
    inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    };

    outputs = { self, nixpkgs }:
      let
        system = "x86_64-linux";
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.${system}.default = pkgs.mkShell {
          packages = with pkgs; [
            python313 # Exakte Python Version
            uv        # Python Package Manager
            just      # Task Runner
            ruff      # Formatter & Linter
          ];
        };
      };
  }
  ```
]

Dadurch wird sichergestellt, dass alle Entwickler im Team exakt denselben Compiler, dieselbe Python-Version und dieselben Systembibliotheken verwenden. Dies erfüllt das Prinzip der *Dev/Prod Parity* der #htl3r.long[twelvefactor]-Methodik @12factor.

=== Verwaltung von Python-Paketen: Die hermetische Shell
Ein häufiges Problem bei klassischen virtuellen Umgebungen ist, dass sie oft ungewollt auf systemweit installierte Bibliotheken zurückgreifen. Um dies zu verhindern und gleichzeitig die Performance moderner Tools zu nutzen, kombinieren wir #htl3r.long[nix] mit #htl3r.long[uv] @astral-uv.

In diesem Setup übernimmt #htl3r.long[uv] die Rolle des Dependency Managers: Es löst die Abhängigkeiten auf und friert deren Versionen in der `uv.lock` Datei ein. #htl3r.long[nix] geht jedoch einen entscheidenden Schritt weiter als die bloße Bereitstellung von Werkzeugen. Es konstruiert basierend auf diesen Definitionen eine vollständig *#htl3r.long[hermetic]e Shell*.

Innerhalb dieser von #htl3r.long[nix] gebauten Umgebung existiert eine Python-Instanz, die strikt isoliert ist. Dieser Interpreter hat technisch *keinen Zugriff* auf globale Systempakete (z. B. in `/usr/lib/python3.13`) oder lokale Nutzer-Installationen. Er "sieht" ausschließlich jene Bibliotheken, die im Projekt explizit definiert wurden. Dies garantiert absolute Reinheit: Wenn eine Bibliothek nicht in der Konfiguration steht, kann sie im Code nicht importiert werden, selbst wenn sie auf dem Host-Computer des Entwicklers zufällig vorhanden wäre. Dies eliminiert eine ganze Klasse von Fehlern, die durch unsaubere Umgebungen entstehen.

== Automatische Umgebung mit Direnv
Obwohl #htl3r.long[nix] eine mächtige Umgebung bereitstellt, wäre das manuelle Aktivieren der Shell (via `nix develop`) im Arbeitsalltag umständlich. Hier kommt #htl3r.long[direnv] zum Einsatz.

#htl3r.long[direnv] ist eine Shell-Erweiterung, die Verzeichnisse überwacht. Sobald ein Entwickler mit dem Terminal in das Projektverzeichnis wechselt, lädt #htl3r.long[direnv] automatisch die in der Datei `.envrc` definierten Umgebungsvariablen und aktiviert die #htl3r.long[nix]-Umgebung @direnv-docs.

Der Inhalt der `.envrc` ist in unserem Projekt denkbar einfach:
#htl3r.code(
  caption: [Inhalt einer `.envrc`-Datei für das automatische Aktivieren einer #htl3r.long[nix-shell]],
  description: `.envrc`,
)[
  ```bash
  use flake
  ```
]

Dies lädt im Hintergrund vollautomatisch die in der `flake.nix` definierte Umgebung. Umgebungsvariablen werden gesetzt und Tools (wie `python` oder #htl3r.long[just]) werden in den `PATH` injiziert. Verlässt man das Verzeichnis, wird die Umgebung wieder entladen.

== Task-Automation mit Just
Um wiederkehrende Aufgaben wie das Starten des Servers, das Ausführen von Tests oder das Formatieren des Codes zu vereinfachen, setzen wir auf den Command-Runner #htl3r.long[just] @just-command-runner.

Im Gegensatz zu Make, das primär für Build-Prozesse in C/C++ gedacht ist, ist #htl3r.long[just] ein moderner, sprachenunabhängiger Task-Runner. Die Befehle werden in einem justfile definiert. Dies dient gleichzeitig als "lebende Dokumentation" für alle verfügbaren Entwicklungsbefehle.

Die folgende Konfiguration im `justfile` demonstriert die Umsetzung dieser Vereinfachung:

#htl3r.code(caption: [Auszug unseres `justfile`'s], description: `justfile`)[
  ```just
  alias m := manage
  alias s := serve

  manage *args:
      #!/usr/bin/env bash
      if [ -n "$IN_NIX_SHELL" ]; then
          python manage.py {{args}}
      else
          uv run manage.py {{args}}
      fi

  serve:
      @just manage runserver

  migrate:
      @just manage makemigrations
      @just manage migrate
  ```
]

Das Kernstück dieses Skripts ist die bedingte Logik innerhalb des `manage`-Rezepts. Es prüft dynamisch, ob die #htl3r.long[nix-shell] bereits aktiv ist (`IN_NIX_SHELL`) und wählt daraufhin die korrekte Ausführungsumgebung, entweder direkt via `python` oder gekapselt mittels #htl3r.long[uv] run. Für den Entwickler reduziert sich der Aufwand signifikant: Ein einfaches `just migrate` genügt, um sowohl die Erstellung der Migrationen als auch deren Anwendung auf die Datenbank durchzuführen. Diese Abstraktion verringert nicht nur die kognitive Belastung, sondern minimiert auch Fehlerquellen und spart über die Projektlaufzeit hinweg wertvolle Zeit.

== Ganzheitliche Code-Qualität durch Treefmt
In einem Projekt wie diesem, das Python (Backend), HTML/JavaScript (Frontend) und #htl3r.long[nix] (Infrastruktur) vereint, ist die Einhaltung eines konsistenten Code-Stils eine Herausforderung. Unterschiedliche Sprachen erfordern unterschiedliche Tools, was oft zu komplexen Toolchains führt.

Um dies zu vereinheitlichen, setzen wir #htl3r.long[treefmt] ein @treefmt-docs. #htl3r.long[treefmt] fungiert als Meta-Formatter, der anhand der Dateiendung das passende Werkzeug aufruft. Unsere Konfiguration (`nix/treefmt.nix`) orchestriert dabei:
- *#htl3r.long[ruff]* für Python-Code.
- *#htl3r.long[prettier]* für CSS & JS.
- *#htl3r.long[djlint]* für HTML-Templates.
- *#htl3r.long[nixfmt]* für #htl3r.long[nix]-Dateien.

Durch den Befehl `nix fmt` wird #htl3r.long[treefmt] angestoßen und formatiert das gesamte Repository in einem Durchgang. Dies eliminiert Diskussionen über Einrückungen oder Klammersetzung ("Bikeshedding") im Team vollständig und automatisiert die Einhaltung der Richtlinien.

== Vorteile der gewählten Architektur
Die Kombination aus #htl3r.long[nix], #htl3r.long[direnv] und #htl3r.long[just] bietet signifikante Vorteile gegenüber traditionellen Setups.

=== Onboarding-Geschwindigkeit
Ohne dieses Setup müsste ein neuer Entwickler:
+ Die exakte Python-Version manuell installieren und Konflikte mit dem System-Python vermeiden.
+ Eine virtuelle Umgebung (`venv`) anlegen und aktivieren.
+ Abhängigkeiten manuell via `pip` oder #htl3r.long[uv] synchronisieren.
+ Notwendige Umgebungsvariablen für die Konfiguration manuell setzen.

Bei *DiagNet* klont ein Entwickler das Repository und betritt den Ordner. Das System installiert *alles* automatisch. Die "Time-to-Code" sinkt von Stunden auf Minuten.

=== Identische Umgebungen (Dev/Prod Parity)
Ein entscheidender Vorteil dieser Architektur ist die Garantie, dass die lokale Entwicklungsumgebung exakt der Umgebung in der #htl3r.full[ci] entspricht. Da die #htl3r.short[ci]-Pipeline dieselbe `flake.nix` nutzt, um ihre Testumgebung aufzubauen, sind Versionskonflikte zwischen Entwickler-Laptop und Build-Server ausgeschlossen. Tests, die lokal bestehen, werden mit an Sicherheit grenzender Wahrscheinlichkeit auch in der Pipeline erfolgreich sein. (Für Details zur Implementierung der #htl3r.short[ci]-Pipelines siehe @cicd_pipelines).

=== Tooling-Konsistenz
Da Tools wie Linter oder Formatierer ebenfalls über #htl3r.long[nix] bereitgestellt werden, gibt es keine Diskussionen mehr über Code-Formatierung. Jeder Entwickler nutzt erzwungenermaßen dieselbe Version des Formatierers, was "Format Wars" in Pull Requests verhindert.
