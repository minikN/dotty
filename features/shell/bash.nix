{ lib, mkFeature, ... }:

mkFeature {
  name = "bash";

  options = { pkgs, ... }: {
    package = lib.mkPackageOption pkgs "bash" { default = [ "bashInteractive" ]; };
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra lines appended to .bash_profile.";
    };
  };

  globals = { config, ... }: {
    apps.shell = lib.mkIf
      (config.features.bash.enable && !config.features.zsh.enable)
      "${config.features.bash.package}/bin/bash";
  };

  home = { config, lib, pkgs, ... }: {
    assertions = [{
      assertion = !(config.features.bash.enable && config.features.zsh.enable);
      message = "features.bash and features.zsh cannot both be enabled. Pick one.";
    }];

    features.ls.enable = lib.mkDefault true;

    home.packages = [
      config.features.bash.package
      pkgs.bash-completion
    ];

    programs.bash = {
      enable = true;
      historyFile = "${config.xdg.stateHome}/bash/history";
      profileExtra = config.features.bash.extraConfig;
      bashrcExtra = ''
        ## bash-completion: standard completion definitions
        [[ $- == *i* && -r ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh ]] && \
          source ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh
      '';
    };

    home.activation.createBashHistoryDir =
      lib.hm.dag.entryAfter [ "writeBoundary" ]
        "run mkdir -p ${lib.escapeShellArg "${config.xdg.stateHome}/bash"}";
  };
}
