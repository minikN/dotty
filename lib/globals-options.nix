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
    };
  };
}
