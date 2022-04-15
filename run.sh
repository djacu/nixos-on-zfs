#!/run/current-system/sw/bin/bash -xe

nix-channel --update

nix-shell

poetry install

nix-build

$(nix-build --no-out-link)/bin/python