# brave-browser-flake

A Nix flake for Brave Browser variants

## Quick Start

Add flake to inputs:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  brave-flake.url = "github:git404x/brave-browser-flake";
};
```

### home-manager

```nix
{
  # The module automatically injects the overlay, use pkgs.bravePackages
  imports = [ inputs.brave-flake.homeManagerModules.default ];

  programs.brave-browser = {
    enable = true;
    # options: brave, brave-beta, brave-origin, brave-origin-beta
    package = pkgs.bravePackages.brave-origin;

    extensions = [
      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
    ];

    commandLineArgs = [ "--disable-features=WebRtcAllowInputVolumeAdjustment" ];
  };
}
```

### NixOS

```nix
{
  # The module automatically injects the overlay
  imports = [ inputs.brave-flake.nixosModules.default ];

  programs.brave-browser = {
    enable = true;
    package = pkgs.bravePackages.brave-origin;
  };
}
```
