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

      storeDir = mkOption {
        type = types.str;
        default = "${config.features.user.homeDirectory}/.gnupg";
        description = ''
          GnuPG home directory (sets `programs.gpg.homedir` and
          GNUPGHOME). Defaults to `~/.gnupg` to match home-manager's
          default — change to e.g. `"''${config.features.xdg.baseDirs.dataHome}/gnupg"`
          for an XDG-clean layout, but migrate the existing keyring
          before deploying or you'll lose access.
        '';
      };

      keychainInteraction = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether pinentry-mac should offer to save the passphrase to
          the macOS Keychain (darwin only). Toggled via a launchd
          agent that runs `defaults write org.gpgtools.pinentry-mac …`
          at login.
        '';
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
        ## pinentry-mac stores its keychain preference in macOS
        ## defaults, not gpg-agent.conf. A launchd agent at login
        ## writes the user's choice so subsequent passphrase prompts
        ## honour it.
        launchd.agents.pinentry-keychainIntegration = {
          enable = true;
          config = {
            Label = "org.dotty.pinentry-keychainIntegration";
            RunAtLoad = true;
            ProgramArguments = [
              (pkgs.writeShellScript "pinentry-keychainIntegration" ''
                export PATH="/bin:/usr/bin:/usr/local/bin"
                defaults write org.gpgtools.pinentry-mac UseKeychain -bool ${if cfg.keychainInteraction then "YES" else "NO"}
                defaults write org.gpgtools.pinentry-mac DisableKeychain -bool ${if cfg.keychainInteraction then "NO" else "YES"}
              '').outPath
            ];
          };
        };
      })
    ];
}
