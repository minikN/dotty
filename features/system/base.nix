{ lib, mkFeature, ... }:

let
  inherit (lib) mkOption types;

  sharedNix = {
    extraOptions = ''
      experimental-features = nix-command flakes
      warn-dirty = false
    '';
  };
in
mkFeature {
  name = "base";
  enableByDefault = true;

  options = {
    timeZone = mkOption {
      type = types.str;
      default = "Europe/Berlin";
      description = "System time zone.";
    };
    locale = mkOption {
      type = types.str;
      default = "en_US.UTF-8";
      description = "Default locale.";
    };
  };

  nixos = { config, ... }: {
    time.timeZone = config.features.base.timeZone;
    i18n.defaultLocale = config.features.base.locale;
    nix = sharedNix;
  };

  darwin = { config, pkgs, ... }: {
    time.timeZone = config.features.base.timeZone;
    nix = sharedNix // { package = pkgs.lix; };
  };
}
