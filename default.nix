{ pkgs ? import <nixpkgs> {} }:

pkgs.poetry2nix.mkPoetryEnv {

  projectDir = ./.;
  python = pkgs.python310;

}
