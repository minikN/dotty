{ lib, mkFeature, ... }:

let
  defaultSchemes = {
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
in
mkFeature {
  name = "theme";

  options = { config, ... }:
    let
      inherit (lib) mkOption types;
    in
    {
      polarity = mkOption {
        type = types.enum [ "light" "dark" ];
        default = "light";
        description = "Theme polarity.";
      };

      scheme = mkOption {
        type = types.attrsOf types.str;
        default = defaultSchemes.${config.features.theme.polarity};
        description = ''
          Base16 color scheme (16 hex strings, base00..base0F).
          Defaults to a light or dark scheme based on `polarity`.
        '';
      };
    };
}
