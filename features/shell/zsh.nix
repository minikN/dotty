{ lib, mkFeature, ... }:

mkFeature {
  name = "zsh";

  options = { pkgs, ... }: {
    package = lib.mkPackageOption pkgs "zsh" { };
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra lines appended to .zprofile.";
    };
  };

  globals = { config, ... }: {
    apps.shell = lib.mkIf config.features.zsh.enable
      "${config.features.zsh.package}/bin/zsh";
  };

  home = { config, ... }: {
    programs.zsh = {
      enable = true;
      package = config.features.zsh.package;
      enableCompletion = true;
      syntaxHighlighting.enable = true;
      profileExtra = config.features.zsh.extraConfig;
    };
  };
}
