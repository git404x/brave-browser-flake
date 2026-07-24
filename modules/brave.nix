{
  isHomeManager ? false,
}:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.brave-browser;

  extensionOpts = lib.types.submodule {
    options = {
      id = lib.mkOption {
        type = lib.types.str;
        description = "Extension ID.";
      };
      updateUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://clients2.google.com/service/update2/crx";
        description = "Update URL.";
      };
    };
  };

  policy = {
    ExtensionSettings = lib.listToAttrs (
      map (ext: {
        name = ext.id;
        value = {
          installation_mode = "force_installed";
          update_url = ext.updateUrl;
        };
      }) cfg.extensions
    );
  };

  wrappedPackage = pkgs.symlinkJoin {
    name = "${cfg.package.name}-wrapped";
    paths = [ cfg.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/${cfg.package.meta.mainProgram} \
        ${lib.optionalString (
          cfg.commandLineArgs != [ ]
        ) "--add-flags ${lib.escapeShellArg (lib.concatStringsSep " " cfg.commandLineArgs)}"}
    '';
  };
in
{
  options.programs.brave-browser = {
    enable = lib.mkEnableOption "Brave Browser variants";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bravePackages.brave-origin;
      defaultText = lib.literalExpression "pkgs.bravePackages.brave-origin";
      description = "The Brave variant package to install.";
    };

    extensions = lib.mkOption {
      type = lib.types.listOf extensionOpts;
      default = [ ];
      description = "List of extensions to install via policy.";
    };

    commandLineArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Command line args to append.";
    };
  };

  config = lib.mkIf cfg.enable (
    if isHomeManager then {
      home.packages = [ wrappedPackage ];

      xdg.configFile."BraveSoftware/Brave-Browser/policies/managed/policy.json" = lib.mkIf (cfg.extensions != [ ]) {
        text = builtins.toJSON policy;
      };
    } else {
      environment.systemPackages = [ wrappedPackage ];

      environment.etc."brave/policies/managed/policy.json" = lib.mkIf (cfg.extensions != [ ]) {
        text = builtins.toJSON policy;
      };
    }
  );
}
