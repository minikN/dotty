{ lib, mkFeature, ... }:

let
  inherit (lib) mkOption types;
in
mkFeature {
  name = "nas";

  options = {
    host = mkOption {
      type = types.str;
      default = "192.168.178.26";
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
        temp = "Temp";
      };
      description = "Mount-name → remote-share-name map.";
    };
  };

  nixos = { config, pkgs, ... }:
    let
      cfg = config.features.nas;
      automountOpts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      mountOpts = [
        "${automountOpts},credentials=${toString cfg.credentialsFile},uid=1000,gid=100"
      ];
    in
    {
      environment.systemPackages = [ pkgs.cifs-utils ];

      fileSystems = lib.mapAttrs'
        (mount: remote: lib.nameValuePair "${cfg.mountBase}/${mount}" {
          device = "//${cfg.host}/${remote}";
          fsType = "cifs";
          options = mountOpts;
        })
        cfg.shares;
    };
}
