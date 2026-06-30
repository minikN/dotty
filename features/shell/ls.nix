{ lib, mkFeature, ... }:

mkFeature {
  name = "ls";

  home = { config, lib, pkgs, ... }:
    let
      isDarwin = config.globals.platform == "darwin";
      ## Use GNU ls (gls) on darwin; BSD ls can't group-directories-first.
      binary = if isDarwin then "gls" else "ls";
    in
    {
      home.packages = lib.optional isDarwin pkgs.coreutils-prefixed;
      home.shellAliases.ls = "${binary} --color=auto --group-directories-first";
    };
}
