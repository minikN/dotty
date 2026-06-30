{ lib, mkFeature, ... }:

let
  inherit (lib) mkOption types;
in
mkFeature {
  name = "keyboard";

  options = {
    layout = mkOption {
      description = "Keyboard layout.";
      default = {
        name = "us";
        options = [ "ctrl:nocaps" ];
      };
      type = types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            default = "us";
            description = "XKB layout (comma-separated for multi-layout; tty uses first).";
          };
          variant = mkOption {
            type = types.str;
            default = "";
            description = "XKB variant (e.g. dvorak, nodeadkeys).";
          };
          options = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "XKB options (e.g. ctrl:nocaps).";
          };
        };
      };
    };
  };

  nixos = { config, ... }:
    let
      cfg = config.features.keyboard.layout;
    in
    {
      console.keyMap = builtins.elemAt (lib.splitString "," cfg.name) 0;

      ## Read by display managers + X11; Wayland compositors set their own.
      services.xserver.xkb = {
        inherit (cfg) variant;
        layout = cfg.name;
        options = lib.concatStringsSep "," cfg.options;
      };
    };

  darwin = { config, ... }:
    let
      cfg = config.features.keyboard.layout;
    in
    {
      system.keyboard.enableKeyMapping = true;
      system.keyboard.remapCapsLockToControl =
        builtins.elem "ctrl:nocaps" cfg.options;
    };

  home = { config, ... }:
    let
      cfg = config.features.keyboard.layout;
    in
    {
      home.keyboard = {
        layout = cfg.name;
        inherit (cfg) options variant;
      };
    };
}
