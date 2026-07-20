{ lib, pkgs, ... }@args:

let
  versions = lib.importJSON ../versions.json;
in
lib.mapAttrs (pname: config:
  pkgs.callPackage ./brave.nix (config // { inherit pname; })
) versions
