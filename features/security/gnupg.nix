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
        description = "List of GPG keygrips to expose via gpg-agent's SSH socket.";
      };

      defaultTtl = mkOption {
        type = types.int;
        default = 86400;
        description = "Cache TTL for GnuPG passphrases, in seconds.";
      };

      pinentryPackage = mkOption {
        type = types.nullOr types.package;
        default =
          if config.globals.platform == "darwin"
          then pkgs.pinentry_mac
          else pkgs.pinentry-qt;
        description = "Pinentry program for passphrase prompts.";
      };
    };

  home = { config, ... }:
    let
      cfg = config.features.gnupg;
    in
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

      programs.gpg.enable = true;
    };
}
