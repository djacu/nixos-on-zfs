{
  description = "An application to assist in installing NixOS on ZFS.";

  nixConfig.bash-prompt = "\[nix-develop\]$ ";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.poetry2nix.url = "github:nix-community/poetry2nix";
  inputs.poetry2nix.inputs.flake-utils.follows = "flake-utils";
  inputs.poetry2nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  inputs.pre-commit-hooks.inputs.flake-utils.follows = "flake-utils";
  inputs.pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    flake-compat,
    poetry2nix,
    pre-commit-hooks,
  }:
    flake-utils.lib.eachSystem [flake-utils.lib.system.x86_64-linux] (
      system: let
        overlays = [
          poetry2nix.overlay
        ];

        pkgs = import nixpkgs {
          inherit overlays system;
        };

        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = self;
          hooks = {
            alejandra.enable = true;
            black.enable = true;
            isort.enable = true;
            unittest = {
              enable = true;
              name = "unittest";
              description = "Python unit testing.";
              entry = "${pybootstrapEnv}/bin/python -m unittest";
              types = ["file" "python"];
            };
          };
        };

        pythonEnv = pkgs.python310;

        pybootstrapEnv = pkgs.poetry2nix.mkPoetryEnv {
          projectDir = ./.;
          python = pythonEnv;
          editablePackageSources = {
            pybootstrap = ./pybootstrap;
          };
        };

        pybootstrapApp = pkgs.poetry2nix.mkPoetryApplication {
          projectDir = ./.;
          python = pythonEnv;
        };
      in {
        packages.default = pybootstrapEnv;

        apps.default.program = "${pybootstrapApp}/bin/pybootstrap";
        apps.default.type = "app";

        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;

          packages = with pkgs; [
            pybootstrapEnv
            python310Packages.poetry
          ];
        };

        checks = {
          inherit pre-commit-check;
        };
      }
    );
}
