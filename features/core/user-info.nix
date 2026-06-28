{ lib, mkFeature, ... }:

let
  inherit (lib) mkOption types;
in
mkFeature {
  name = "userInfo";
  enableByDefault = true;

  options = { config, ... }: {
    username = mkOption {
      type = types.str;
      default = config.globals.user.user or "user";
      description = "Username.";
    };
    fullName = mkOption {
      type = types.str;
      default = config.globals.user.fullName or "";
      description = "Full name.";
    };
    email = mkOption {
      type = types.str;
      default = config.globals.user.email or "";
      description = "Email address.";
    };
    homeDirectory = mkOption {
      type = types.str;
      default =
        if config.globals.platform == "darwin"
        then "/Users/${config.features.userInfo.username}"
        else "/home/${config.features.userInfo.username}";
      description = "Home directory.";
    };
    extraGroups = mkOption {
      type = types.listOf types.str;
      default = [ "wheel" ];
      description = "Extra NixOS groups.";
    };
  };

  nixos = { config, ... }: {
    users.users.${config.features.userInfo.username} = {
      isNormalUser = true;
      home = config.features.userInfo.homeDirectory;
      description = config.features.userInfo.fullName;
      extraGroups = config.features.userInfo.extraGroups;
    };
  };

  darwin = { config, ... }: {
    users.users.${config.features.userInfo.username} = {
      home = config.features.userInfo.homeDirectory;
      description = config.features.userInfo.fullName;
    };
  };

  home = { config, ... }: {
    home.username = lib.mkDefault config.features.userInfo.username;
    home.homeDirectory = lib.mkDefault config.features.userInfo.homeDirectory;
  };
}
