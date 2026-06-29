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

      ## GUI apps launched from Dock/Spotlight inherit env vars from the
      ## user's launchd session, not from a shell's startup files. Push
      ## the home-manager-managed env into the launchd session at login
      ## so GUI apps (and the terminals they spawn) see the same PATH +
      ## variables as a fresh login shell.
      launchd.agents.session-environment = {
        enable = true;
        config = {
          Label = "home-manager.session-environment";
          RunAtLoad = true;
          ProgramArguments =
            let
              script = pkgs.writeShellScript "session-environment" ''
                export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

                ## Replicate what a fresh login shell would build up:
                ##   /etc/profile -> /etc/bashrc -> nix-darwin's
                ##     setEnvironment, contributing nix store paths.
                ##   ~/.profile  -> hm-session-vars.sh + any shell
                ##     feature's profileExtra (e.g. /opt/homebrew/bin,
                ##     $HOME/.local/bin).
                ## Then publish the resulting PATH into the launchd
                ## session so GUI apps inherit the same PATH as Terminal.
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
