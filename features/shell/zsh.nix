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

  ## Enable nix-darwin/NixOS's system-level zsh module so /etc/zprofile
  ## and /etc/zshrc are generated. Without this on NixOS, login zsh
  ## shells never see `environment.loginShellInit` (which is what wires
  ## up things like `features.home.autoStartWmOnTty`). On darwin this
  ## is the default anyway.
  nixos = _: { programs.zsh.enable = true; };

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
