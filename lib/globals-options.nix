{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.globals = {
    user = mkOption {
      type = types.attrs;
      description = "Static globals from globals.nix.";
    };
    platform = mkOption {
      type = types.enum [ "nixos" "darwin" ];
      description = "Host platform.";
    };
    wayland = mkOption {
      type = types.bool;
      default = false;
      description = "Host runs a Wayland session.";
    };
    apps = {
      shell           = mkOption { type = types.nullOr types.str; default = null; description = "System shell."; };
      terminal        = mkOption { type = types.nullOr types.str; default = null; description = "System terminal."; };
      editor          = mkOption { type = types.nullOr types.str; default = null; description = "System editor."; };
      wm              = mkOption { type = types.nullOr types.str; default = null; description = "System window manager."; };
      launcher        = mkOption { type = types.nullOr types.str; default = null; description = "System app launcher."; };
      bar             = mkOption { type = types.nullOr types.str; default = null; description = "System status bar."; };
      passwordManager = mkOption { type = types.nullOr types.str; default = null; description = "System password manager."; };
    };

    autoloads = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Commands fed into the WM's startup block.";
    };

    wmControlledBar = mkOption {
      type = types.bool;
      default = false;
      description = "WM spawns the bar; bar features skip their own systemd service.";
    };
  };
}
