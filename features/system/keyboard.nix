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
            description = ''
              XKB layout name. Accepts a comma-separated list for
              multi-layout setups (e.g. "us,de") — the tty console uses
              the first entry.
            '';
          };
          variant = mkOption {
            type = types.str;
            default = "";
            description = "XKB layout variant (e.g. \"dvorak\", \"nodeadkeys\").";
          };
          options = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              XKB options (e.g. "ctrl:nocaps", "grp:alt_space_toggle").
            '';
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
      ## tty console keymap — take the first entry of a multi-layout name.
      console.keyMap = builtins.elemAt (lib.splitString "," cfg.name) 0;

      ## XKB settings for the graphical session. Wayland compositors
      ## (sway, hyprland, …) typically set their own xkb config and
      ## ignore these, but display managers (sddm, gdm, greetd) and any
      ## X11 fallback still read these options.
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
      ## Honour the XKB `ctrl:nocaps` option on macOS too — system
      ## keyboard preferences will report CapsLock as Control.
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
