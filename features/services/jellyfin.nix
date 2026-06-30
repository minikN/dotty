{ lib, mkFeature, ... }:

let
  inherit (lib) mkEnableOption mkOption types;
in
mkFeature {
  name = "jellyfin";

  options = {
    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open 8096/tcp, 8920/tcp, 1900/udp (DLNA), 7359/udp (discovery).";
    };

    hardwareAcceleration = mkEnableOption "VA-API hardware video transcoding" // {
      default = true;
    };

    mediaGroups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra groups for the jellyfin user (e.g. for NAS access).";
    };
  };

  nixos = { config, pkgs, ... }:
    let
      cfg = config.features.jellyfin;
    in
    lib.mkMerge [
      {
        services.jellyfin = {
          enable = true;
          openFirewall = cfg.openFirewall;
        };

        ## .NET DataProtection persists its key ring under $HOME.
        systemd.services.jellyfin.environment.HOME =
          config.services.jellyfin.dataDir;

        ## VA-API drivers; i965 for pre-Skylake, intel-media-driver for newer.
        hardware.graphics = lib.mkIf cfg.hardwareAcceleration {
          enable = true;
          extraPackages = with pkgs; [
            intel-media-driver
            intel-vaapi-driver
            libva-vdpau-driver
            libvdpau-va-gl
          ];
        };

        users.users.jellyfin.extraGroups =
          lib.optionals cfg.hardwareAcceleration [ "render" "video" ]
          ++ cfg.mediaGroups;
      }

      ## Register a fail2ban jail against jellyfin's auth-denied log lines.
      (lib.mkIf config.features.fail2ban.enable {
        environment.etc."fail2ban/filter.d/jellyfin.conf".text = ''
          [Definition]
          failregex = ^.*Authentication request .* has been denied .*\(IP: <HOST>\)\.
          journalmatch = _SYSTEMD_UNIT=jellyfin.service
        '';

        services.fail2ban.jails.jellyfin.settings = {
          enabled = true;
          backend = "systemd";
          filter = "jellyfin";
          maxretry = 5;
          findtime = 600;
        };
      })
    ];
}
