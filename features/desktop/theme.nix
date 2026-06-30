{ lib, mkFeature, ... }:

let
  mkSchemeAttrs = import ../../lib/mk-scheme-attrs.nix { inherit lib; };

  rawSchemes = {
    light = {
      base00 = "ffffff"; base01 = "f0f0f0"; base02 = "e0e0e0"; base03 = "c2c2c2";
      base04 = "c4c4c4"; base05 = "000000"; base06 = "595959"; base07 = "9f9f9f";
      base08 = "a60000"; base09 = "f5d0a0"; base0A = "6f5500"; base0B = "00663f";
      base0C = "005e8b"; base0D = "3548cf"; base0E = "e07fff"; base0F = "624416";
    };
    dark = {
      base00 = "000000"; base01 = "1e1e1e"; base02 = "313131"; base03 = "303030";
      base04 = "646464"; base05 = "ffffff"; base06 = "e0e0e0"; base07 = "0000c0";
      base08 = "ff5f59"; base09 = "ff6b55"; base0A = "d0bc00"; base0B = "6ae4b9";
      base0C = "00d3d0"; base0D = "79a8ff"; base0E = "b6a0ff"; base0F = "7a6100";
    };
  };

  other = polarity: if polarity == "dark" then "light" else "dark";
in
mkFeature {
  name = "theme";

  options = { config, ... }:
    let
      inherit (lib) mkEnableOption mkOption types;
    in
    {
      polarity = mkOption {
        type = types.enum [ "light" "dark" ];
        default = "light";
        description = "Theme polarity.";
      };

      scheme = mkOption {
        type = types.attrsOf types.str;
        apply = mkSchemeAttrs;
        default = rawSchemes.${config.features.theme.polarity};
        description = "Base16 scheme (plain hex; `scheme.withHashtag.*` exposes the `#`-prefixed form).";
      };

      defaultSchemes = mkOption {
        type = types.attrs;
        readOnly = true;
        default = lib.mapAttrs (_: mkSchemeAttrs) rawSchemes;
        description = "Built-in light/dark schemes for consumers that need both palettes.";
      };

      wallpaper = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Wallpaper path; null falls back to a solid colour from `scheme`.";
      };

      enableToggle = mkEnableOption "runtime light/dark switching via NixOS specialisation";
    };

  nixos = { config, ... }:
    let
      cfg = config.features.theme;
      otherPolarity = other cfg.polarity;
    in
    lib.mkIf cfg.enableToggle {
      ## NOPASSWD so toggle-theme can flip specialisations without prompting.
      security.sudo.extraRules = [{
        runAs = "root";
        groups = [ "wheel" ];
        commands = [
          {
            command = "/nix/var/nix/profiles/system/specialisation/${otherPolarity}/bin/switch-to-configuration switch";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/nix/var/nix/profiles/system/bin/switch-to-configuration switch";
            options = [ "NOPASSWD" ];
          }
        ];
      }];

      ## Sibling config with polarity flipped; activated by toggle-theme.
      specialisation.${otherPolarity}.configuration = {
        features.theme.polarity = lib.mkForce otherPolarity;
        features.theme.scheme = lib.mkForce rawSchemes.${otherPolarity};
      };
    };

  home = { config, pkgs, ... }:
    let
      cfg = config.features.theme;
      otherPolarity = other cfg.polarity;
      toggler = pkgs.writeShellScriptBin "toggle-theme" ''
        current=$(readlink /run/current-system)
        specialisation=$(readlink /nix/var/nix/profiles/system/specialisation/${otherPolarity})
        if [ "$current" = "$specialisation" ] || [ -z "$specialisation" ]; then
          sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
        else
          sudo /nix/var/nix/profiles/system/specialisation/${otherPolarity}/bin/switch-to-configuration switch
        fi
      '';
    in
    lib.mkIf cfg.enableToggle {
      home.packages = [ toggler ];
      xdg.desktopEntries.toggle-theme = {
        name = "Toggle Theme";
        exec = "${toggler}/bin/toggle-theme";
      };
    };
}
