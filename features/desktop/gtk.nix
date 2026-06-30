{ lib, mkFeature, ... }:

mkFeature {
  name = "gtk";

  options = { config, pkgs, ... }:
    let
      inherit (lib) mkOption types;
      themeModule = types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Theme name.";
          };
          package = mkOption {
            type = types.package;
            description = "Theme package.";
          };
        };
      };
    in
    {
      defaultThemes = mkOption {
        type = types.attrsOf themeModule;
        description = "Built-in light/dark GTK themes (consumed by `theme` default).";
        default = {
          light = {
            name = "adw-gtk3";
            package = pkgs.adw-gtk3;
          };
          dark = {
            name = "adw-gtk3-dark";
            package = pkgs.adw-gtk3;
          };
        };
      };

      theme = mkOption {
        type = themeModule;
        description = "Active GTK theme. Defaults to one of `defaultThemes` based on `features.theme.polarity`.";
        default = config.features.gtk.defaultThemes.${config.features.theme.polarity};
      };

      iconTheme = mkOption {
        type = themeModule;
        description = "Icon theme.";
        default = {
          name = "Adwaita";
          package = pkgs.adwaita-icon-theme;
        };
      };

      cursorTheme = mkOption {
        type = themeModule;
        description = "Cursor theme.";
        default = {
          name = "Bibata-Modern-${
            if config.features.theme.polarity == "dark" then "Classic" else "Ice"
          }";
          package = pkgs.bibata-cursors;
        };
      };

      cursorSize = mkOption {
        type = types.int;
        default = 24;
        description = "Cursor size in pixels.";
      };

      extraCss = mkOption {
        type = types.lines;
        default = "";
        description = "Extra CSS appended for every GTK version.";
      };

      extraConfig = mkOption {
        type = with types; attrsOf (oneOf [ bool int str ]);
        default = { };
        description = "Extra settings written to gtk{3,4}/settings.ini.";
      };
    };

  home = { config, pkgs, ... }:
    let
      cfg = config.features.gtk;
    in
    {
      home.packages = with pkgs; [
        dconf
        gnome-tweaks
      ];

      home.pointerCursor = lib.mkDefault {
        inherit (cfg.cursorTheme) name package;
        size = cfg.cursorSize;
        gtk.enable = true;
      };

      gtk = {
        enable = true;
        inherit (cfg) theme iconTheme cursorTheme;
      }
      ## extraCss/extraConfig apply identically to gtk3 and gtk4.
      // lib.genAttrs [ "gtk3" "gtk4" ] (lib.const {
        inherit (cfg) extraCss extraConfig;
      });
    };
}
