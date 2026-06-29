{ lib, mkFeature, ... }:

mkFeature {
  name = "ls";

  home = { config, lib, pkgs, ... }:
    let
      isDarwin = config.globals.platform == "darwin";
      ## BSD ls (apple) can't group directories first; pull in GNU ls
      ## via coreutils-prefixed which installs g-prefixed binaries
      ## (gls, gcat, …) without clobbering Apple's defaults.
      binary = if isDarwin then "gls" else "ls";
    in
    {
      home.packages = lib.optional isDarwin pkgs.coreutils-prefixed;
      home.shellAliases.ls = "${binary} --color=auto --group-directories-first";
    };
}
