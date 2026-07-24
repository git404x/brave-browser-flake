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

  configDir =
    "BraveSoftware/"
    + (
      if cfg.package.pname == "brave-origin" then
        "Brave-Origin"
      else if cfg.package.pname == "brave-origin-beta" then
        "Brave-Origin-Beta"
      else if cfg.package.pname == "brave-beta" then
        "Brave-Browser-Beta"
      else
        "Brave-Browser"
    );

  extensionJson = ext: {
    name = "${configDir}/External Extensions/${ext.id}.json";
    value.text = builtins.toJSON {
      external_update_url = ext.updateUrl;
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

  wrappedPackage =
    if cfg.commandLineArgs != [ ] then
      cfg.package.override {
        commandLineArgs = lib.concatStringsSep " " cfg.commandLineArgs;
      }
    else
      cfg.package;
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
    if isHomeManager then
      {
        home.packages = [ wrappedPackage ];

        xdg.configFile = lib.mkIf (cfg.extensions != [ ]) (
          lib.listToAttrs (map extensionJson cfg.extensions)
        );
      }
    else
      {
        environment.systemPackages = [ wrappedPackage ];

        # System level still uses /etc/brave/policies which works fine
        environment.etc."brave/policies/managed/policy.json" = lib.mkIf (cfg.extensions != [ ]) {
          text = builtins.toJSON policy;
        };

        # Also add it for the specific pname in case it diverges
        environment.etc."${cfg.package.pname}/policies/managed/policy.json" =
          lib.mkIf (cfg.extensions != [ ])
            {
              text = builtins.toJSON policy;
            };
      }
  );
}
