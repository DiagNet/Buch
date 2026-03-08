#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Karun Sandhu")
= Development & Environment <dev_env>

Ein wiederkehrendes Problem in Teamprojekten ist die schleichende Divergenz zwischen den Entwicklungsumgebungen einzelner Teammitglieder. Pakete werden in unterschiedlichen Versionen installiert, Umgebungsvariablen fehlen oder sind falsch gesetzt, und ein Fehler, der auf einem Rechner reproduzierbar ist, tritt auf einem anderen gar nicht auf @jetbrains-config-drift. Um dieses Problem von Grund auf auszuschließen, setzt #htl3r.long[diagnet] auf einen vollständig deklarativen Ansatz: Die Entwicklungsumgebung ist nicht dokumentiert, sondern im Code definiert und damit zwingend reproduzierbar.

== Reproduzierbarkeit durch Nix
Das Fundament bildet der Paketmanager #htl3r.long[nix]. Im Gegensatz zu herkömmlichen, imperativen Paketmanagern, die globale Zustände im Betriebssystem verändern, isoliert #htl3r.long[nix] jede Abhängigkeit in einem eigenen, unveränderlichen Pfad im sogenannten _#htl3r.long[nix-store]_ (z. B. `/nix/store/bfs3...-python-3.13`). Dieser Ansatz basiert auf dem funktionalen Deployment-Modell, bei dem Softwarekomponenten als unveränderliche Werte betrachtet werden @dolstra-nix. Konflikte zwischen verschiedenen Versionen derselben Bibliothek sind damit strukturell ausgeschlossen, da jede Version unter einem eigenen Hash-Pfad liegt und nie eine andere überschreibt @nixos-homepage.

=== Nix Flakes
Für die Versionierung der Abhängigkeiten kommen #htl3r.long[nix-flakes] zum Einsatz. Zwei Dateien im Repository bilden dabei die vollständige Spezifikation der Umgebung: `flake.nix` definiert die *Inputs* (z. B. Paketquellen wie `nixpkgs`) und die *Outputs* (z. B. die Entwicklungsumgebung `devShell`). `flake.lock` fixiert die exakten Hash-Werte aller verwendeten Pakete, analog zu `package-lock.json` in JavaScript-Projekten.

Nachfolgend ein vereinfachter Auszug aus der Konfiguration, der zeigt, wie Python und externe Tools einer #htl3r.long[nix-shell] hinzugefügt werden:

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

Da die `flake.nix` von allen Entwicklern und der #htl3r.full[ci]-Pipeline gleichermaßen verwendet wird, ist sichergestellt, dass Compiler, Python-Version und Systembibliotheken überall identisch sind. Das entspricht dem Prinzip der *Dev/Prod Parity* aus der #htl3r.long[twelvefactor]-Methodik @12factor. Da die Pipeline dieselbe `flake.nix` nutzt, sind Versionskonflikte zwischen Entwickler-Laptop und Build-Server strukturell ausgeschlossen. Tests, die lokal bestehen, bestehen auch in der Pipeline (für die konkrete Pipeline-Implementierung siehe @cicd_pipelines).

=== Verwaltung von Python-Paketen: Die hermetische Shell
Klassische virtuelle Python-Umgebungen lösen das Isolationsproblem nur teilweise: Sie kapseln zwar installierte Pakete, greifen aber weiterhin auf systemweit verfügbare Bibliotheken zurück, wenn ein Paket fehlt. Für #htl3r.long[diagnet] wurde deshalb #htl3r.long[nix] mit #htl3r.long[uv] kombiniert @astral-uv.

#htl3r.long[uv] übernimmt dabei die Rolle des Dependency Managers: Es löst die Abhängigkeiten auf und fixiert deren Versionen in der `uv.lock`-Datei. #htl3r.long[nix] baut darauf aufbauend eine vollständig *#htl3r.longpl[hermetic] Shell*: Der Python-Interpreter hat technisch *keinen Zugriff* auf globale Systempakete (z. B. in `/usr/lib/python3.13`) oder lokale Nutzer-Installationen. Er sieht ausschließlich jene Bibliotheken, die im Projekt explizit deklariert wurden. Eine Bibliothek, die nicht in der Konfiguration steht, lässt sich nicht importieren, selbst wenn sie auf dem Host-Rechner zufällig installiert ist.

== Automatische Umgebung mit Direnv
Das manuelle Aktivieren der Shell via `nix develop` bei jedem Wechsel ins Projektverzeichnis wäre im Arbeitsalltag zu umständlich. #htl3r.long[direnv] löst dieses Problem: Die Shell-Erweiterung überwacht Verzeichnisse und lädt beim Betreten des Projektordners automatisch die in `.envrc` definierten Umgebungsvariablen sowie die #htl3r.long[nix]-Umgebung @direnv-docs.

Der Inhalt der `.envrc` beschränkt sich auf eine einzige Zeile:
#htl3r.code(
  caption: [Inhalt einer `.envrc`-Datei für das automatische Aktivieren einer Nix Shell],
  description: `.envrc`,
)[
  ```bash
  use flake
  ```
]

`use flake` weist #htl3r.long[direnv] an, die in der `flake.nix` definierte Umgebung zu laden, Umgebungsvariablen zu setzen und Tools wie `python` oder #htl3r.long[just] in den `PATH` einzutragen. Verlässt man das Verzeichnis, wird die Umgebung wieder entladen. Für einen neuen Entwickler bedeutet das: Repository klonen, in den Ordner wechseln, und die vollständige Entwicklungsumgebung steht bereit, ohne manuelle Installationsschritte.

== Task-Automation mit Just
Für wiederkehrende Aufgaben wie das Starten des Servers, das Ausführen von Tests oder das Anlegen von Datenbankmigrationen kommt der Command-Runner #htl3r.long[just] zum Einsatz @just-command-runner. Anders als `make`, das primär für Build-Prozesse in C/C++ ausgelegt ist, ist #htl3r.long[just] sprachenunabhängig und hat keine impliziten Abhängigkeitsannahmen. Die Rezepte im `justfile` dienen gleichzeitig als maschinenlesbare Dokumentation aller verfügbaren Entwicklungsbefehle.

#htl3r.code(caption: [Auszug unseres `justfile`s], description: `justfile`)[
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

Das `manage`-Rezept prüft über die Variable `IN_NIX_SHELL`, ob die #htl3r.long[nix]-Umgebung aktiv ist, und wählt daraufhin den passenden Ausführungspfad: entweder direkt via `python` oder gekapselt über `uv run`. Damit funktioniert dasselbe Rezept sowohl innerhalb als auch außerhalb der #htl3r.long[nix-shell] korrekt. `just migrate` führt `makemigrations` und `migrate` in einem Schritt aus; `just s` startet den integrierten Django-Server.

== Einheitliche Code-Qualität durch Treefmt
#htl3r.long[diagnet] vereint drei Sprachen mit jeweils eigenen Formatter-Anforderungen: Python im Backend, HTML/JavaScript im Frontend und #htl3r.long[nix] für die Infrastruktur. Jede Sprache hat etablierte Formatter-Tools, aber ohne eine gemeinsame Steuerungsschicht müssten diese separat konfiguriert und aufgerufen werden.

#htl3r.long[treefmt] löst dieses Problem als Meta-Formatter: Anhand der Dateiendung ruft es das jeweils passende Werkzeug auf @treefmt-docs. Die Konfiguration in `nix/treefmt.nix` bindet dabei #htl3r.long[ruff] für Python-Code, #htl3r.long[prettier] für CSS & JS, #htl3r.long[djlint] für HTML-Templates und #htl3r.long[nixfmt] für #htl3r.long[nix]-Dateien ein.

Ein einzelner Aufruf von #box(`nix fmt`) formatiert damit das gesamte Repository in einem Durchgang. Diskussionen über Einrückungen oder Klammersetzung erübrigen sich, da das Ergebnis deterministisch ist.
