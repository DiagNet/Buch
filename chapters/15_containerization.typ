#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Karun Sandhu")
= Deployment & Operations <deployment_operations>
#htl3r.long[diagnet] wird als Container-Image ausgeliefert, dessen Abhängigkeiten vollständig durch #htl3r.long[nix] fixiert sind. Die automatisierte #htl3r.short[ci]/#htl3r.full[cd]-Pipeline übernimmt Build, Test und Veröffentlichung bei jeder Codeänderung (siehe @cicd_pipelines).

== Containerisierung <containerization>
Das Container-Image wird direkt durch #htl3r.long[nix] gebaut, wobei jede Abhängigkeit durch einen kryptographischen Hash im #htl3r.long[nix]-Store fixiert ist, nicht durch einen Versionsnamen. Damit gilt dieselbe Garantie wie für die Entwicklungsumgebung (siehe @dev_env): Die #htl3r.long[nix]-Derivation, die lokal gebaut wird, landet byte-identisch in der Registry.

=== Image-Erstellung mit `pkgs.dockerTools`
Für den Build kommt `pkgs.dockerTools.buildLayeredImage` aus `nixpkgs` zum Einsatz @nix-docker-tools. Im Vergleich zu `buildImage`, das das gesamte Dateisystem in eine einzige Schicht packt, teilt `buildLayeredImage` das Image anhand des Abhängigkeitsgraphen automatisch in mehrere unveränderliche Schichten auf. Pakete wie `cryptography` oder `pyats`, die sich zwischen Builds nicht ändern, werden dabei in stabilen Layern gebündelt, die das Container-Registry nach dem ersten Push dauerhaft im Cache vorhält. Nur der Applikationscode selbst erzeugt bei jedem Build eine neue Schicht. Bei einem reinen Code-Push wird damit nur diese eine Schicht übertragen, während die Abhängigkeits-Layer gecacht bleiben.

Das resultierende Image ist #htl3r.full[oci]-kompatibel, trägt den Tag `diagnet:dev` und enthält die `venv`-Derivation mit dem fertig kompilierten Python-Environment inklusive aller Abhängigkeiten aus der `uv.lock`-Datei sowie die `entrypoint`-Derivation mit dem Startup-Skript.

#htl3r.code(
  caption: [Aufbau der `buildLayeredImage`-Konfiguration],
  description: `nix/diagnet.nix`,
)[
  ```nix
  pkgs.dockerTools.buildLayeredImage {
    name = "diagnet";
    tag = "dev";
    contents = [
      pkgs.dockerTools.fakeNss  # minimale /etc/passwd für POSIX-Kompatibilität
      pkgs.bashInteractive
      pkgs.cacert               # CA-Zertifikate für TLS-Verbindungen
      pkgs.coreutils
      pkgs.openssh              # für pyATS SSH-Verbindungen zu Netzwerkgeräten
      pkgs.inetutils            # für pyATS ping-Funktionalität
      entrypoint
      ../.                      # Quellcode des Projekts
    ];
    config = {
      Cmd = [ "${entrypoint}/bin/entrypoint" ];
      WorkingDir = "/";
      Env = [
        "DIAGNET_SETTINGS_MODULE=diagnet.settings"
        "DIAGNET_STATIC_ROOT=/nix/store/...-diagnet-static"
        "DIAGNET_ALLOWED_HOSTS=localhost,127.0.0.1"
        "DIAGNET_DATA_PATH=/data"
        "DIAGNET_DEBUG=False"
      ];
      ExposedPorts."8000/tcp" = { };
    };
  }
  ```
]

#pagebreak()

=== Statische Assets zur Build-Zeit
Django's `collectstatic` sammelt alle statischen Dateien aus den installierten Apps und kopiert sie in ein gemeinsames Verzeichnis, von dem aus sie ausgeliefert werden. In #htl3r.long[diagnet] übernimmt das #htl3r.long[whitenoise], das die Dateien direkt aus dem #htl3r.full[asgi]-Prozess heraus serviert, ohne separaten Webserver @whitenoise-docs. Dieser Schritt wird als eigenständige #htl3r.long[nix]-Derivation (`staticRoot`) bereits zur Build-Zeit ausgeführt:

#htl3r.code(
  caption: [Generierung statischer Assets als Nix-Derivation zur Build-Zeit],
  description: `nix/diagnet.nix`,
)[
  ```nix
  staticRoot = stdenv.mkDerivation {
    name = "diagnet-static";
    src = pythonSet.diagnet.src;
    nativeBuildInputs = [ venv ];
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      export DIAGNET_SECRET_KEY="django-insecure-fallback-key-for-dev-only"
      export DIAGNET_DEVICE_ENCRYPTION_KEY="8OGs8CTrNq8TltpMA3H-..."
      env DIAGNET_STATIC_ROOT="$out" python manage.py collectstatic \
        --noinput --clear
    '';
  };
  ```
]

Der resultierende Store-Pfad wird als `DIAGNET_STATIC_ROOT` direkt in die Image-Konfiguration eingebrannt. Zur Laufzeit liest Django die Dateien aus dem unveränderlichen #htl3r.long[nix]-Store-Pfad. Die Dummy-Schlüssel in der `installPhase` sind nötig, weil `settings.py` beim Import prüft, ob beide Variablen gesetzt sind. `collectstatic` führt damit keine kryptographischen Operationen durch und wertet diese Werte inhaltlich nicht aus (siehe @data_security).

=== Startup-Logik: Der Entrypoint
Da #htl3r.long[diagnet] persistente Daten und Datenbank-Migrationen benötigt, übernimmt ein Shell-Skript die Initialisierung beim Containerstart. Es prüft zunächst, ob `DIAGNET_DATA_PATH` beschreibbar ist, und bricht mit einem Hinweis auf das `:Z`-Flag für SELinux-Systeme ab, falls nicht.

Die Schlüsselgenerierung läuft in einer Subshell mit `umask 077`, damit die `secrets.env`-Datei von Anfang an mit restriktiven Berechtigungen angelegt wird:

#htl3r.code(
  caption: [Schlüsselgenerierung in der Entrypoint-Subshell],
  description: `nix/diagnet.nix`,
)[
  ```bash
  (
    umask 077
    if [ -z "${DIAGNET_SECRET_KEY:-}" ]; then
      NEW_SECRET=$(python -c \
        'from django.core.management.utils import get_random_secret_key; \
         print(get_random_secret_key())')
      echo "DIAGNET_SECRET_KEY='$NEW_SECRET'" >> "$SECRETS_FILE"
      export DIAGNET_SECRET_KEY="$NEW_SECRET"
    fi
    if [ -z "${DIAGNET_DEVICE_ENCRYPTION_KEY:-}" ]; then
      NEW_KEY=$(python -c \
        'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())')
      echo "DIAGNET_DEVICE_ENCRYPTION_KEY='$NEW_KEY'" >> "$SECRETS_FILE"
      export DIAGNET_DEVICE_ENCRYPTION_KEY="$NEW_KEY"
    fi
  )
  ```
]

Fehlt `DIAGNET_SECRET_KEY`, wird er über `get_random_secret_key()` erzeugt, fehlt `DIAGNET_DEVICE_ENCRYPTION_KEY`, über `Fernet.generate_key()`. Beide Werte werden an `secrets.env` angehängt und danach erneut in die aktuelle Shell gesourct. Bei Folgestarts sind die Variablen bereits gesetzt, sodass die Generierung übersprungen wird.

#pagebreak()

Schlägt `migrate --noinput` fehl, bricht das Skript ab, damit der Container nicht in einen Zustand mit inkonsistentem Datenbankschema startet. Anschließend übernimmt `exec` den Serverstart:

#htl3r.code(
  caption: [Datenbankmigrationen und Serverstart am Ende des Entrypoints],
  description: `nix/diagnet.nix`,
)[
  ```bash
  if ! ${venv}/bin/python /manage.py migrate --noinput; then
    echo "Database migrations failed; aborting startup." >&2
    exit 1
  fi

  exec daphne -b 0.0.0.0 diagnet.asgi:application
  ```
]

Als #htl3r.short[asgi]-Server kommt #htl3r.long[daphne] zum Einsatz, da es das offizielle Server-Tool des Django-Projekts ist @daphne-docs. Das `exec` ersetzt den Shell-Prozess, sodass #htl3r.long[daphne] als #htl3r.full[pid] 1 läuft und `SIGTERM` beim Containershutdown direkt empfängt, ohne auf einen übergeordneten Shell-Prozess warten zu müssen.

=== Lokales Testen des Images
Das `justfile` stellt zwei Befehle bereit, mit denen das Container-Image lokal gebaut und gestartet werden kann:

#htl3r.code(
  caption: [`just`-Befehle zum lokalen Bauen und Starten des Containers],
  description: `justfile`,
)[
  ```just
  [group("container")]
  load-container:
      nix build .#container
      podman load < result

  [group("container")]
  run-container: load-container
      podman compose up --force-recreate
  ```
]

`just load-container` baut das Image via `nix build .#container` und lädt das resultierende Tar-Archiv direkt in Podman. `just run-container` startet den Container anschließend mit der in `compose.yml` definierten Konfiguration, wobei Port 8000 auf den Host weitergeleitet und `./data` als Volume für persistente Daten eingebunden wird. Podman wurde gegenüber Docker bevorzugt: Es läuft rootless und verarbeitet das #htl3r.short[oci]-kompatible Tar-Archiv, das `nix build` erzeugt, direkt über `podman load`, ohne laufenden Docker-Daemon @podman-docs.

=== Distribution über die GitHub Container Registry
Für den Produktionseinsatz wird das Image über die GitHub Container Registry unter `ghcr.io/diagnet/diagnet` verteilt. Der Build- und Veröffentlichungsprozess ist vollständig automatisiert (siehe @cicd_pipelines). Zur Inbetriebnahme genügt eine einzige `compose.yaml`:

#htl3r.code(
  caption: [Minimale `compose.yaml` für den Produktionseinsatz von DiagNet],
  description: `compose.yaml`,
)[
  ```yaml
      services:
        diagnet:
          container_name: diagnet
          image: ghcr.io/diagnet/diagnet:latest
          restart: unless-stopped
          ports:
            - 8000:8000
          volumes:
            - ./data:/data:Z
          environment:
            - DIAGNET_DATA_PATH=/data
            - DIAGNET_ALLOWED_HOSTS=localhost,127.0.0.1
  ```
]

Das `:Z`-Flag am Volume-Mount ist auf SELinux-Systemen notwendig, damit der Container auf das gemountete Verzeichnis schreiben darf.
