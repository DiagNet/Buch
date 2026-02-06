alias w := watch
alias b := build

default:
    @just --list

watch:
    #!/usr/bin/env bash
    if [ -n "$IN_NIX_SHELL" ]; then
        nix run .#watch
    else
        typst watch DiagNet_DA_Buch.typ
    fi

build:
    #!/usr/bin/env bash
    if [ -n "$IN_NIX_SHELL" ]; then
        nix run .#build
    else
        typst compile DiagNet_DA_Buch.typ
    fi
