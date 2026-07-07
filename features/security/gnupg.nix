{ lib, mkFeature, ... }:

mkFeature {
  name = "gnupg";

  options = { config, pkgs, ... }:
    let
      inherit (lib) mkOption types;
    in
    {
      sshKeys = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "GPG keygrips exposed via gpg-agent's SSH socket.";
      };

      defaultTtl = mkOption {
        type = types.int;
        default = 86400;
        description = "Passphrase cache TTL (seconds).";
      };

      pinentryPackage = mkOption {
        type = types.nullOr types.package;
        default =
          if config.globals.platform == "darwin"
          then pkgs.pinentry_mac
          else pkgs.pinentry-qt;
        description = "Pinentry binary used for prompts.";
      };

      storeDir = mkOption {
        type = types.str;
        default = "${config.features.user.homeDirectory}/.gnupg";
        description = "GNUPGHOME / programs.gpg.homedir. Migrate keyring before changing.";
      };

      keychainInteraction = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to offer to save the password in the system keychain (darwin only).";
      };
    };

  home = { config, lib, pkgs, ... }:
    let
      cfg = config.features.gnupg;
    in
    lib.mkMerge [
      {
        services.gpg-agent = {
          enable = true;
          enableSshSupport = true;
          sshKeys = cfg.sshKeys;
          defaultCacheTtl = cfg.defaultTtl;
          defaultCacheTtlSsh = cfg.defaultTtl;
          maxCacheTtl = cfg.defaultTtl;
          maxCacheTtlSsh = cfg.defaultTtl;
          pinentry.package = cfg.pinentryPackage;
        };

        programs.gpg = {
          enable = true;
          homedir = cfg.storeDir;
        };
      }

      (lib.mkIf (config.globals.platform == "darwin") {
        home.activation.pinentryKeychain = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD /usr/bin/defaults write org.gpgtools.pinentry-mac UseKeychain -bool ${if cfg.keychainInteraction then "YES" else "NO"}
          $DRY_RUN_CMD /usr/bin/defaults write org.gpgtools.pinentry-mac DisableKeychain -bool ${if cfg.keychainInteraction then "NO" else "YES"}
        '';
      })
    ];
}
