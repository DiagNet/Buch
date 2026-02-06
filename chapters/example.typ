// Has to be imported for function use
#import "@preview/htl3r-da:2.0.0" as htl3r

#htl3r.author("Max Mustermann")
= Chapter Title
Hier kann ein Kapitel der #htl3r.full[da] geschrieben werden.

```nix
{
  description = "A Typst project";

  outputs = {
    nixpkgs,
    typix,
    flake-utils,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      typixLib = typix.lib.${system};

      src = ./.;
      commonArgs = {
        typstSource = "main.typ";

        fontPaths = [
          "${pkgs.source-code-pro}/share/fonts/opentype"
          "${pkgs.vista-fonts}/share/fonts/truetype"
          "${pkgs.font-awesome}/share/fonts/opentype"
        ];

        virtualPaths = [];
      };

      typstPackagesSrc = "${inputs.typst-packages}/packages";
      typstPackagesCache = pkgs.stdenv.mkDerivation {
        name = "typst-packages-cache";
        src = typstPackagesSrc;
        dontBuild = true;
        installPhase = ''
          mkdir -p "$out/typst/packages"
          cp -LR --reflink=auto --no-preserve=mode -t "$out/typst/packages" "$src"/*
        '';
      };

      # Compile a Typst project, *without* copying the result
      # to the current directory
      build-drv = typixLib.buildTypstProject (commonArgs
        // {
          inherit src;
          XDG_CACHE_HOME = typstPackagesCache;
        });

      # Compile a Typst project, and then copy the result
      # to the current directory
      build-script = typixLib.buildTypstProjectLocal (commonArgs
        // {
          inherit src;
          XDG_CACHE_HOME = typstPackagesCache;
        });

      # Watch a project and recompile on changes
      watch-script = typixLib.watchTypstProject commonArgs;
    in {
      checks = {
        inherit build-drv build-script watch-script;
      };

      packages.default = build-drv;

      apps = rec {
        default = watch;
        build = flake-utils.lib.mkApp {
          drv = build-script;
        };
        watch = flake-utils.lib.mkApp {
          drv = watch-script;
        };
      };

      devShells.default = typixLib.devShell {
        inherit (commonArgs) fontPaths virtualPaths;
        packages = [
          # WARNING: Don't run `typst-build` directly, instead use `nix run .#build`
          # See https://github.com/loqusion/typix/issues/2
          # build-script
          watch-script
          # More packages can be added here, like typstfmt
          pkgs.typst-fmt
          pkgs.tinymist
        ];
      };
    });

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    typix = {
      url = "github:loqusion/typix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    typst-packages = {
      url = "github:typst/packages";
      flake = false;
    };
  };
}
```
