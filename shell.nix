{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = [ pkgs.hugo ];
  shellHook = ''hugo server -D'';
}
