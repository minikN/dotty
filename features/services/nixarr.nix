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
    transmission = mkEnableOption "the Transmission download client, confined to the VPN";

    peerPort = mkOption {
      type = types.port;
      default = 50000;
      description = "Transmission peer port. Set to the port your VPN provider forwards to you.";
    };
  };

  nixos = { config, inputs, ... }:
    let
      cfg = config.features.nixarr;
    in
    {
      imports = [ inputs.nixarr.nixosModules.default ];

      assertions = [{
        assertion = cfg.wgConf != null;
        message = "features.nixarr.wgConf must be set when the feature is enabled.";
      }];

      nixarr = {
        enable = true;

        vpn = {
          enable = true;
          wgConf = cfg.wgConf;
          vpnTestService.enable = cfg.vpnTestService;
        };

        transmission = {
          enable = cfg.transmission;
          peerPort = cfg.peerPort;
          vpn.enable = cfg.transmission;
        };
      };
    };
}
