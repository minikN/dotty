{ lib, mkFeature, ... }:

let
  inherit (lib) mkOption types;
in
mkFeature {
  name = "caddy";

  options = { config, ... }: {
    email = mkOption {
      type = types.str;
      default = config.globals.user.email;
      description = "ACME registration email; defaults to globals.user.email.";
    };

    vhosts = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          backend = mkOption {
            type = types.str;
            description = "Upstream URL, e.g. http://127.0.0.1:8096.";
          };
          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = "Extra Caddyfile directives inside the vhost block.";
          };
        };
      });
      default = { };
      description = "FQDN → reverse-proxy upstream.";
    };
  };

  nixos = { config, ... }:
    let
      cfg = config.features.caddy;
    in
    {
      networking.firewall.allowedTCPPorts = [ 80 443 ];

      services.caddy = {
        enable = true;
        email = cfg.email;
        virtualHosts = lib.mapAttrs
          (_: v: {
            extraConfig = ''
              reverse_proxy ${v.backend}
              ${v.extraConfig}
            '';
          })
          cfg.vhosts;
      };
    };
}
