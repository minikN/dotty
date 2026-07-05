{ lib, mkFeature, ... }:

let
  inherit (lib) mkOption types;
in
mkFeature {
  name = "nas";

  options = {
    host = mkOption {
      type = types.str;
      default = "10.0.0.11";
      description = "Hostname or IP of the NAS.";
    };
    mountBase = mkOption {
      type = types.str;
      default = "/mnt/nas";
      description = "Base directory where NAS shares are mounted.";
    };
    credentialsFile = mkOption {
      type = types.path;
      default = "/etc/nixos/smb-credentials";
      description = "Path to the SMB credentials file.";
    };
    shares = mkOption {
      type = types.attrsOf types.str;
      default = {
        movies = "movies";
        shows = "shows";
        music = "music";
        audiobooks = "audiobooks";
        temp = "temp";
      };
      description = "Mount-name → remote-share-name map.";
    };
  };

  nixos = { config, pkgs, ... }:
    let
      cfg = config.features.nas;
      cifsOptions = "credentials=${toString cfg.credentialsFile},uid=1000,gid=100,file_mode=0664,dir_mode=0775";
    in
    {
      environment.systemPackages = [ pkgs.cifs-utils ];
      system.fsPackages = [ pkgs.cifs-utils ];

      systemd.mounts = lib.mapAttrsToList
        (mount: remote: {
          what = "//${cfg.host}/${remote}";
          where = "${cfg.mountBase}/${mount}";
          type = "cifs";
          options = cifsOptions;
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          mountConfig.TimeoutSec = 45;
          unitConfig.StartLimitIntervalSec = 0;
        })
        cfg.shares;

      systemd.automounts = lib.mapAttrsToList
        (mount: _remote: {
          where = "${cfg.mountBase}/${mount}";
          wantedBy = [ "multi-user.target" ];
        })
        cfg.shares;
    };
}
