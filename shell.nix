{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {

  buildInputs = [
    pkgs.python310
    pkgs.python310Packages.poetry
  ];

}
