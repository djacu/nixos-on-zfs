#!/run/current-system/sw/bin/bash -xe

sudo nix-channel --update

nix-shell

poetry install

nix-build

sudo $(nix-build --no-out-link)/bin/python