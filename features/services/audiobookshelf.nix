{ lib, mkFeature, ... }:

let
  inherit (lib) mkOption types;
in
mkFeature {
  name = "audiobookshelf";

  options = {
    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the audiobookshelf port in the firewall.";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Bind address. 127.0.0.1 to restrict to localhost (caddy-only).";
    };

    mediaGroups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra groups for the audiobookshelf user (e.g. for NAS access).";
    };
  };

  nixos = { config, ... }:
    let
      cfg = config.features.audiobookshelf;
    in
    lib.mkMerge [
      {
        services.audiobookshelf = {
          enable = true;
          openFirewall = cfg.openFirewall;
          host = cfg.host;
        };

        users.users.audiobookshelf.extraGroups = cfg.mediaGroups;
      }

      ## Register a fail2ban jail against the [LocalAuth] failed-login lines.
      (lib.mkIf config.features.fail2ban.enable {
        environment.etc."fail2ban/filter.d/audiobookshelf.conf".text = ''
          [Definition]
          failregex = ^.*\[LocalAuth\] Failed login attempt .* from ip <HOST>
          journalmatch = _SYSTEMD_UNIT=audiobookshelf.service
        '';

        services.fail2ban.jails.audiobookshelf.settings = {
          enabled = true;
          backend = "systemd";
          filter = "audiobookshelf";
          maxretry = 5;
          findtime = 600;
        };
      })
    ];
}
