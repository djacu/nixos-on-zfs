{
  description = "An applicatoin to assist in installing NixOS on ZFS.";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.poetry2nix.url = "github:nix-community/poetry2nix";
  inputs.poetry2nix.inputs.flake-utils.follows = "flake-utils";
  inputs.poetry2nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    poetry2nix,
  }:
    flake-utils.lib.eachSystem [flake-utils.lib.system.x86_64-linux] (
      system: let
        overlays = [
          poetry2nix.overlay
        ];

        pkgs = import nixpkgs {
          inherit overlays system;
        };

        pybootstrapEnv = pkgs.poetry2nix.mkPoetryEnv {
          projectDir = ./.;
          python = pkgs.python310;
          editablePackageSources = {
            pybootstrap = ./pybootstrap;
          };
        };

        pybootstrapApp = pkgs.poetry2nix.mkPoetryApplication {
          projectDir = ./.;
          python = pkgs.python310;
        };
      in {
        packages.default = pybootstrapEnv;

        apps.default.program = "${pybootstrapApp}/bin/pybootstrap";
        apps.default.type = "app";

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            python310
            python310Packages.poetry
          ];
        };
      }
    );
}
