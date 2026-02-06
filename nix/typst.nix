{ inputs, ... }:
{
  perSystem =
    {
      system,
      config,
      pkgs,
      ...
    }:
    let
      typixLib = inputs.typix.lib.${system};

      src = ../.;
      commonArgs = {
        typstSource = "DiagNet_DA_Buch.typ";

        fontPaths = [
          "${pkgs.source-code-pro}/share/fonts/opentype"
          "${pkgs.vista-fonts}/share/fonts/truetype"
          "${pkgs.font-awesome}/share/fonts/opentype"
        ];

        virtualPaths = [ ];
      };

      unstable_typstPackages = [
        {
          name = "codly-languages";
          version = "0.1.7";
          hash = "sha256-R1nvXVeYq/ssRfvNZ8Ct+tlnQ15bWlciS0bxDzeaKRU=";
        }
        {
          name = "codly";
          version = "1.2.0";
          hash = "sha256-2SQnoece+GcxiJfZeqt+4kkOr5UVZ80jCBMIycSimlw=";
        }
        {
          name = "htl3r-da";
          version = "2.0.0";
          hash = "sha256-Md7ScnOof4JojGDn6zPW9KOHSvRTFw7RY+qsx1IfdkI=";
        }
      ];

      # Compile a Typst project, *without* copying the result
      # to the current directory
      build-drv = typixLib.buildTypstProject (
        commonArgs
        // {
          inherit src unstable_typstPackages;
        }
      );

      # Compile a Typst project, and then copy the result
      # to the current directory
      build-script = typixLib.buildTypstProjectLocal (
        commonArgs
        // {
          inherit src unstable_typstPackages;
        }
      );

      # Watch a project and recompile on changes
      watch-script = typixLib.watchTypstProject commonArgs;
    in
    {
      checks = {
        inherit build-drv build-script watch-script;
      };

      packages.default = build-drv;

      apps = rec {
        default = watch;
        build = inputs.flake-utils.lib.mkApp {
          drv = build-script;
        };
        watch = inputs.flake-utils.lib.mkApp {
          drv = watch-script;
        };
      };

      devShells.default = typixLib.devShell {
        shellHook = ''
          ${config.pre-commit.settings.shellHook}
        '';

        inherit (commonArgs) fontPaths virtualPaths;
        packages = [
          # WARNING: Don't run `typst-build` directly, instead use `nix run .#build`
          # See https://github.com/loqusion/typix/issues/2
          # build-script
          watch-script
          pkgs.just
        ];
      };
    };
}
