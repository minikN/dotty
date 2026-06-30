{ lib, mkFeature, ... }:

let
  inherit (lib) mkIf mkMerge mkOption types;
in
mkFeature {
  name = "home";
  enableByDefault = true;

  options = {
    autostartWmOnTTY = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "exec the configured WM on this tty at login (NixOS).";
    };
  };

  nixos = { config, ... }:
    let
      shell = config.globals.apps.shell;
      wm = config.globals.apps.wm;
      tty = config.features.home.autostartWmOnTTY;
      user = config.features.user.username;
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
      user = config.features.user.username;
    in
    {
      system.primaryUser = user;

      environment.shells = mkIf (shell != null) [ shell ];
      users.users.${user}.shell = mkIf (shell != null) shell;

      ## chsh as root every activation — nix can't change macOS login shells.
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

      ## Push the user's PATH + sessionVariables into launchd so Dock-
      ## launched GUI apps see the same env as a login shell.
      launchd.agents.session-environment = {
        enable = true;
        config = {
          Label = "home-manager.session-environment";
          RunAtLoad = true;
          ProgramArguments =
            let
              script = pkgs.writeShellScript "session-environment" ''
                export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                [ -r /etc/profile ]    && . /etc/profile
                [ -r "$HOME/.profile" ] && . "$HOME/.profile"
                launchctl setenv PATH "$PATH"

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
