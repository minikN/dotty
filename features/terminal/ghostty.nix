{ lib, mkFeature, ... }:

mkFeature {
  name = "ghostty";

  options = { config, pkgs, ... }: {
    package = lib.mkOption {
      type = lib.types.package;
      default =
        if config.globals.platform == "darwin"
        then pkgs.ghostty-bin
        else pkgs.ghostty;
      defaultText = lib.literalExpression "ghostty-bin on darwin, ghostty on linux";
      description = "Ghostty package for the current platform.";
    };
  };

  globals = { config, ... }: {
    apps.terminal = lib.mkIf config.features.ghostty.enable (lib.mkForce (
      if config.globals.platform == "darwin"
      then "${config.features.ghostty.package}/Applications/Ghostty.app/Contents/MacOS/ghostty"
      else "${config.features.ghostty.package}/bin/ghostty"
    ));
  };

  home = { config, ... }:
    let
      mono = config.features.font.fonts.monospace;
      hex = config.features.theme.scheme.withHashtag;
    in
    {
      programs.ghostty = {
        enable = true;
        package = config.features.ghostty.package;

        settings = {
          theme = "dotty";

          window-padding-x = 8;
          window-padding-y = 8;

          font-family = mono.name;
          font-style = "Regular";

          font-family-bold = mono.name;
          font-style-bold = "Bold";

          font-family-italic = mono.name;
          font-style-italic = "Italic";

          font-family-bold-italic = mono.name;
          font-style-bold-italic = "Bold Italic";

          font-size = mono.size;
        };

        themes.dotty = with hex; {
          background = base00;
          cursor-color = base05;
          foreground = base05;
          palette = [
            "0=${base05}"
            "1=${base08}"
            "2=${base0B}"
            "3=${base0A}"
            "4=${base0D}"
            "5=${base0E}"
            "6=${base0C}"
            "7=${base05}"
            "8=${base03}"
            "9=${base08}"
            "10=${base0B}"
            "11=${base0A}"
            "12=${base0D}"
            "13=${base0E}"
            "14=${base0C}"
            "15=${base06}"
          ];
          selection-background = base02;
          selection-foreground = base05;
        };
      };
    };
}
