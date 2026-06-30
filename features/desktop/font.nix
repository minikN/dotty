{ lib, mkFeature, ... }:

mkFeature {
  name = "font";

  options = { config, pkgs, ... }:
    let
      inherit (lib) mkOption types;
      fontModule = types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Font family name.";
          };
          package = mkOption {
            type = types.nullOr types.package;
            default = null;
            description = "Font package; null to skip install (e.g. OS-shipped).";
          };
          size = mkOption {
            type = types.int;
            default = 11;
            description = "Size in points.";
          };
        };
      };
    in
    {
      fonts = {
        monospace = mkOption {
          type = fontModule;
          description = "Monospace font.";
          default = {
            name = "Iosevka Nerd Font Mono";
            package = pkgs.nerd-fonts.iosevka;
            size = 15;
          };
        };
        serif = mkOption {
          type = fontModule;
          description = "Serif font.";
          default = {
            name = "IBM Plex Sans";
            package = pkgs.ibm-plex;
            size = 11;
          };
        };
        sans = mkOption {
          type = fontModule;
          description = "Sans-serif font.";
          default = config.features.font.fonts.serif;
        };
        unicode = mkOption {
          type = fontModule;
          description = "Unicode / emoji font.";
          ## On darwin use Apple Color Emoji; noto-fonts-color-emoji's
          ## afdko build is broken on aarch64-darwin.
          default =
            if config.globals.platform == "darwin"
            then { name = "Apple Color Emoji"; package = null; size = 11; }
            else { name = "Noto Color Emoji"; package = pkgs.noto-fonts-color-emoji; size = 11; };
        };
      };
    };

  home = { config, lib, pkgs, ... }:
    let
      cfg = config.features.font.fonts;
    in
    {
      fonts.fontconfig = {
        enable = true;
        defaultFonts = {
          monospace = [ cfg.monospace.name ];
          serif = [ cfg.serif.name ];
          sansSerif = [ cfg.sans.name ];
          emoji = [ cfg.unicode.name ];
        };
      };

      home.packages = lib.filter (p: p != null) (with pkgs; [
        cfg.monospace.package
        cfg.serif.package
        cfg.sans.package
        cfg.unicode.package
        dejavu_fonts
        unifont
        font-awesome
      ]);
    };
}
