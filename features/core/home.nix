{ lib, mkFeature, ... }:

let
  inherit (lib) mkIf mkMerge mkOption types;
in
mkFeature {
  name = "home";
  enableByDefault = true;

  options = {
    autoStartWmOnTty = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "If set, exec the configured WM when logging in on this tty (NixOS).";
    };
  };

  nixos = { config, ... }:
    let
      shell = config.globals.apps.shell;
      wm = config.globals.apps.wm;
      tty = config.features.home.autoStartWmOnTty;
      user = config.features.userInfo.username;
    in
    {
      environment.shells = mkIf (shell != null) [ shell ];
      users.users.${user}.shell = mkIf (shell != null) shell;

      environment.loginShellInit = mkIf (tty != null && wm != null) ''
        [[ $(tty) == ${tty} ]] && exec ${wm}
      '';
    };

  darwin = { config, ... }:
    let
      shell = config.globals.apps.shell;
      user = config.features.userInfo.username;
    in
    {
      system.primaryUser = user;

      environment.shells = mkIf (shell != null) [ shell ];
      users.users.${user}.shell = mkIf (shell != null) shell;

      ## Nix doesn't create users on macOS, so it can't change their login
      ## shell either. Force it on every activation via a launchd daemon
      ## that runs `chsh` as root.
      launchd.daemons.defaultShell = {
        path = [ "/bin" "/usr/bin" "/usr/local/bin" ];
        serviceConfig.RunAtLoad = true;
        serviceConfig.UserName = "root";
        script = ''
          chsh -s ${if shell != null then shell else "/bin/zsh"} ${user}
        '';
      };
    };

  home = { config, pkgs, ... }: mkMerge [
    {
      programs.home-manager.enable = true;
    }
    (mkIf (config.globals.platform == "darwin") {
      targets.darwin = {
        copyApps.enable = true;
        linkApps.enable = false;
      };

      ## GUI apps launched via Spotlight/Finder don't inherit env vars set
      ## in .zprofile. Push the home-manager session variables into the
      ## GUI launchd context at login.
      launchd.agents.session-environment = {
        enable = true;
        config = {
          Label = "home-manager.session-environment";
          RunAtLoad = true;
          ProgramArguments =
            let
              script = pkgs.writeShellScript "session-environment" ''
                export PATH="/bin:/usr/bin:/usr/local/bin"
                ${lib.concatStringsSep "\n" (
                  lib.mapAttrsToList
                    (n: v: "launchctl setenv ${n} \"${v}\"")
                    config.home.sessionVariables
                )}
              '';
            in
            [ "${script}" ];
        };
      };
    })
  ];
}
