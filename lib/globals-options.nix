{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.globals = {
    user = mkOption {
      type = types.attrs;
      description = "User-supplied static globals (from globals.nix).";
    };
    platform = mkOption {
      type = types.enum [ "nixos" "darwin" ];
      description = "Host platform.";
    };
    wayland = mkOption {
      type = types.bool;
      default = false;
      description = "Whether the host runs a Wayland session.";
    };
    apps = {
      shell = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "System-wide shell binary.";
      };
      terminal = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "System-wide terminal.";
      };
      editor = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "System-wide editor.";
      };
      wm = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "System-wide window manager.";
      };
      launcher = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "System-wide application launcher.";
      };
      bar = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "System-wide status bar.";
      };
      passwordManager = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "System-wide password manager front-end.";
      };
    };

    autoloads = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Commands to run automatically when the window manager starts.
        Consumed by WM features (sway, …) and fed into their `startup`
        block.
      '';
    };

    wmControlledBar = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Coordination signal between the WM and the bar feature. Set
        true by the WM feature (e.g. sway) when it spawns the bar
        itself; bar features (e.g. waybar) read this to decide whether
        to run themselves as a standalone user systemd service.
      '';
    };
  };
}
