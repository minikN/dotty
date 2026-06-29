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
    apps.shell = lib.mkIf
      (config.features.zsh.enable && !config.features.bash.enable)
      "${config.features.zsh.package}/bin/zsh";
  };

  home = { config, ... }: {
    assertions = [{
      assertion = !(config.features.bash.enable && config.features.zsh.enable);
      message = "features.bash and features.zsh cannot both be enabled. Pick one.";
    }];

    features.ls.enable = lib.mkDefault true;

    programs.zsh = {
      enable = true;
      package = config.features.zsh.package;
      enableCompletion = true;
      syntaxHighlighting.enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      history.path = "${config.xdg.stateHome}/zsh/history";
      profileExtra = config.features.zsh.extraConfig;
    };
  };
}
