{ lib, mkFeature, ... }:

mkFeature {
  name = "password-store";

  options = { config, pkgs, ... }:
    let
      inherit (lib) mkOption types;
      ## pass-wayland pulls in wl-clipboard so `pass -c` works under Wayland.
      passPkg =
        if config.globals.wayland && config.globals.platform == "nixos"
        then "pass-wayland"
        else "pass";
    in
    {
      package = mkOption {
        type = types.package;
        default = pkgs.${passPkg}.withExtensions (exts: [ exts.pass-otp ]);
        description = "The pass package to use (pass-wayland on Wayland/NixOS), with the pass-otp extension.";
      };

      storeDir = mkOption {
        type = types.str;
        default = "${config.features.xdg.baseDirs.stateHome}/password-store";
        description = "Password store location, exported as PASSWORD_STORE_DIR.";
      };
    };

  home = { config, ... }:
    let
      cfg = config.features.password-store;
    in
    {
      programs.password-store = {
        enable = true;
        package = cfg.package;
        settings.PASSWORD_STORE_DIR = cfg.storeDir;
      };
    };
}
