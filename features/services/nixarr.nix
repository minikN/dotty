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
      description = "WireGuard config for the VPN namespace. Use an agenix runtime path, not a store path";
    };

    vpnTestService = mkEnableOption "the VPN test service (logs public IP + DNS-leak test to `journalctl -u vpn-test-service`)";
    sabnzbd = mkEnableOption "the SABnzbd Usenet download client, confined to the VPN";
    prowlarr = mkEnableOption "Prowlarr (indexer manager)";
    sonarr = mkEnableOption "Sonarr (TV series management)";
    radarr = mkEnableOption "Radarr (movie management)";
    lidarr = mkEnableOption "Lidarr (music management)";

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open enabled services' web-UI ports for LAN access";
    };

    mediaGroups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra groups for the Sonarr/Radarr/Lidarr users (e.g. \"users\" for write access to NAS libraries)";
    };
  };

  nixos = { config, inputs, pkgs, ... }:
    let
      cfg = config.features.nixarr;
      sabnzbdClient = {
        name = "SABnzbd";
        implementation = "Sabnzbd";
        enable = true;
        fields = {
          host = "localhost";
          port = config.nixarr.sabnzbd.guiPort;
          useSsl = false;
          apiKey.secret = config.age.secrets."sabnzbd-api-key".path;
        };
      };

      # upstream lidarr has no sync service; reuse sonarr's
      lidarrSync = pkgs.writers.writePython3Bin "nixarr-sync-lidarr-settings" {
        libraries = [ config.nixarr.nixarr-py.package ];
        flakeIgnore = [ "E501" ];
      } (builtins.replaceStrings [ "sonarr" "Sonarr" ] [ "lidarr" "Lidarr" ]
        (builtins.readFile "${inputs.nixarr}/nixarr/sonarr/settings-sync/sync_settings.py"));

      lidarrSyncConfig = pkgs.writers.writeJSON "lidarr-sync-config.json" {
        # Lidarr's default category "music" doesn't exist in SABnzbd
        download_clients = [ (lib.recursiveUpdate sabnzbdClient { fields.musicCategory = "audio"; }) ];
      };
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
          settings-sync.downloadClients = [ sabnzbdClient ];
        };

        radarr = {
          enable = cfg.radarr;
          openFirewall = cfg.openFirewall;
          settings-sync.downloadClients = [ sabnzbdClient ];
        };

        lidarr = {
          enable = cfg.lidarr;
          openFirewall = cfg.openFirewall;
        };
      };

      services.prowlarr.settings.auth.required = "DisabledForLocalAddresses";
      services.radarr.settings.auth.required = "DisabledForLocalAddresses";
      services.sonarr.settings.auth.required = "DisabledForLocalAddresses";
      services.lidarr.settings.auth.required = "DisabledForLocalAddresses";

      users.users.sonarr.extraGroups = lib.mkIf cfg.sonarr cfg.mediaGroups;
      users.users.radarr.extraGroups = lib.mkIf cfg.radarr cfg.mediaGroups;
      users.users.lidarr.extraGroups = lib.mkIf cfg.lidarr (cfg.mediaGroups ++ [ "lidarr-api" ]);

      # upstream lidarr doesn't sync download clients
      systemd.services.lidarr-sync-config = lib.mkIf cfg.lidarr {
        description = "Sync Lidarr configuration (download clients)";
        after = [ "lidarr-api.service" ];
        wants = [ "lidarr-api.service" ];
        wantedBy = [ "lidarr.service" ];
        serviceConfig = {
          Type = "oneshot";
          User = config.services.lidarr.user;
          Group = config.services.lidarr.group;
          RemainAfterExit = true;
          ExecStart = "${lib.getExe lidarrSync} --config-file ${lidarrSyncConfig}";
        };
      };
    };
}
