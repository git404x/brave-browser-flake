{
  description = "Flake for Brave Browser Variants";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      nixosModules.default = import ./modules/brave.nix { isHomeManager = false; };
      homeManagerModules.default = import ./modules/brave.nix { isHomeManager = true; };
    in
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        bravePackages = pkgs.callPackage ./pkgs/default.nix { };
      in
      {
        packages = bravePackages // {
          default = bravePackages.brave-origin;
        };
      }
    )
    // {
      inherit nixosModules homeManagerModules;

      overlays.default = final: prev: {
        bravePackages = final.callPackage ./pkgs/default.nix { };
        brave = final.bravePackages.brave;
        brave-beta = final.bravePackages.brave-beta;
        brave-origin = final.bravePackages.brave-origin;
        brave-origin-beta = final.bravePackages.brave-origin-beta;
      };
    };
}
