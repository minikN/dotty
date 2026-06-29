{ lib, mkFeature, ... }:

let
  inherit (lib) mkDefault mkEnableOption mkIf mkOption types;
in
mkFeature {
  name = "ssh";

  options = _: {
    daemon = {
      enable = mkEnableOption "the SSH server daemon (sshd)";
      passwordAuthentication = mkOption {
        type = types.bool;
        default = false;
        description = "Allow password (and keyboard-interactive) authentication.";
      };
      permitRootLogin = mkOption {
        type = types.enum [
          "yes" "no" "prohibit-password" "without-password" "forced-commands-only"
        ];
        default = "no";
        description = "Value for sshd's PermitRootLogin.";
      };
    };

    authorizedKeyFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "Public key files authorized for the configured user.";
    };

    matchBlocks = mkOption {
      type = types.attrs;
      default = { };
      description = "SSH client match-block configuration";
    };
  };

  home = { config, ... }: {
    ## Only run ssh-agent if gpg-agent isn't already providing the SSH
    ## socket — avoids two agents fighting over SSH_AUTH_SOCK.
    services.ssh-agent.enable =
      mkDefault (!(config.services.gpg-agent.enableSshSupport or false));

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = config.features.ssh.matchBlocks;
    };
  };

  nixos = { config, ... }: mkIf config.features.ssh.daemon.enable {
    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = config.features.ssh.daemon.passwordAuthentication;
        KbdInteractiveAuthentication = config.features.ssh.daemon.passwordAuthentication;
        PermitRootLogin = config.features.ssh.daemon.permitRootLogin;
      };
    };

    users.users.${config.features.user.username}.openssh.authorizedKeys.keyFiles =
      config.features.ssh.authorizedKeyFiles;
  };
}
