{ lib, mkFeature, ... }:

let
  inherit (lib) mkEnableOption mkOption types literalExpression;
in
mkFeature {
  name = "nixarr";

  options = {
    wgConf = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = literalExpression "config.age.secrets.wg-1.path";
      description = "WireGuard config for the VPN namespace. Use an agenix runtime path, not a store path.";
    };

    vpnTestService = mkEnableOption "the VPN test service (logs public IP + DNS-leak test to `journalctl -u vpn-test-service`)";
    sabnzbd = mkEnableOption "the SABnzbd Usenet download client, confined to the VPN";
    prowlarr = mkEnableOption "Prowlarr (indexer manager)";
    sonarr = mkEnableOption "Sonarr (TV series management)";
    radarr = mkEnableOption "Radarr (movie management)";

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open enabled services' web-UI ports for LAN access.";
    };

    mediaGroups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra groups for the Sonarr/Radarr users (e.g. \"users\" for write access to NAS libraries).";
    };
  };

  nixos = { config, inputs, ... }:
    let
      cfg = config.features.nixarr;
    in
    {
      imports = [ inputs.nixarr.nixosModules.default ];

      assertions = [{
        assertion = cfg.sabnzbd -> cfg.wgConf != null;
        message = "features.nixarr.wgConf must be set when sabnzbd is enabled (it runs in the VPN namespace).";
      }];

      nixarr = {
        enable = true;

        vpn = {
          enable = cfg.sabnzbd;
          wgConf = cfg.wgConf;
          vpnTestService.enable = cfg.vpnTestService;
        };

        sabnzbd = {
          enable = cfg.sabnzbd;
          vpn.enable = cfg.sabnzbd;
          openFirewall = cfg.openFirewall;
          whitelistHostnames = [ config.networking.hostName "localhost" ];
        };

        prowlarr = {
          enable = cfg.prowlarr;
          openFirewall = cfg.openFirewall;
          settings-sync.enable-nixarr-apps = true;
        };

        sonarr = {
          enable = cfg.sonarr;
          openFirewall = cfg.openFirewall;
        };

        radarr = {
          enable = cfg.radarr;
          openFirewall = cfg.openFirewall;
        };
      };

      services.prowlarr.settings.auth.required = "DisabledForLocalAddresses";
      services.radarr.settings.auth.required = "DisabledForLocalAddresses";
      services.sonarr.settings.auth.required = "DisabledForLocalAddresses";

      users.users.sonarr.extraGroups = lib.mkIf cfg.sonarr cfg.mediaGroups;
      users.users.radarr.extraGroups = lib.mkIf cfg.radarr cfg.mediaGroups;
    };
}
