{ lib, mkFeature, ... }:

let
  inherit (lib) mkOption types;
in
mkFeature {
  name = "fail2ban";

  options = {
    bantime = mkOption {
      type = types.str;
      default = "1h";
      description = "Ban duration (e.g. \"1h\", \"24h\", \"-1\" for permanent).";
    };

    ignoreIP = mkOption {
      type = types.listOf types.str;
      default = [
        "127.0.0.1/8"
        "::1"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
      ];
      description = "Addresses never to ban; LAN ranges by default.";
    };
  };

  nixos = { config, ... }:
    let
      cfg = config.features.fail2ban;
    in
    {
      ## Default NixOS sshd jail comes for free; service features can
      ## opt in via `services.fail2ban.jails.<name>` of their own.
      services.fail2ban = {
        enable = true;
        bantime = cfg.bantime;
        ignoreIP = cfg.ignoreIP;
        bantime-increment.enable = true;  ## repeat offenders → exponentially longer bans
      };
    };
}
