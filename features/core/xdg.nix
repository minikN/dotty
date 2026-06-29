{ lib, mkFeature, ... }:

let
  inherit (lib) mkIf mkMerge mkOption types;

  capitalize = s:
    lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (-1) s;
in
mkFeature {
  name = "xdg";
  enableByDefault = true;

  options = { config, ... }:
    let
      home = config.features.userInfo.homeDirectory;
      cap = config.features.xdg.capitalizeUserDirs;
      dir = name: "${home}/${if cap then capitalize name else name}";
    in
    {
      capitalizeUserDirs = mkOption {
        type = types.bool;
        default = config.globals.platform == "darwin";
        description = ''
          Whether to capitalize the basename of XDG user directories
          (Documents, Downloads, …). Defaults to true on darwin to match
          macOS conventions.
        '';
      };

      userDirs = mkOption {
        type = types.attrsOf (types.nullOr types.str);
        description = ''
          XDG user directories. Keys match home-manager's xdg.userDirs
          attribute names. Set an entry to null to omit it.
        '';
        default = {
          desktop = null;
          documents = dir "documents";
          download = dir "downloads";
          music = dir "music";
          pictures = dir "pictures";
          publicShare = dir "public";
          templates = null;
          videos = dir "videos";
        };
      };
    };

  nixos = { config, pkgs, ... }:
    let
      wayland = config.globals.wayland;
    in
    {
      environment.systemPackages = [ pkgs.xdg-utils ];

      xdg.portal = {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ]
          ++ lib.optional wayland pkgs.xdg-desktop-portal-wlr;
        config.common.default = [ "gtk" ] ++ lib.optional wayland "wlr";
        wlr.enable = wayland;
      };
    };

  home = { config, lib, pkgs, ... }:
    let
      cfg = config.features.xdg;
      activeDirs = lib.filterAttrs (_: v: v != null) cfg.userDirs;
    in
    mkMerge [
      { xdg.enable = true; }

      (mkIf (config.globals.platform == "nixos") {
        xdg.mime.enable = true;
        xdg.mimeApps.enable = true;
        xdg.userDirs = activeDirs // {
          enable = true;
          createDirectories = true;
        };
      })

      (mkIf (config.globals.platform == "darwin") {
        home.sessionVariables = lib.filterAttrs (_: v: v != null) {
          XDG_DESKTOP_DIR = cfg.userDirs.desktop or null;
          XDG_DOCUMENTS_DIR = cfg.userDirs.documents or null;
          XDG_DOWNLOAD_DIR = cfg.userDirs.download or null;
          XDG_MUSIC_DIR = cfg.userDirs.music or null;
          XDG_PICTURES_DIR = cfg.userDirs.pictures or null;
          XDG_PUBLICSHARE_DIR = cfg.userDirs.publicShare or null;
          XDG_TEMPLATES_DIR = cfg.userDirs.templates or null;
          XDG_VIDEOS_DIR = cfg.userDirs.videos or null;
        };

        home.activation.createXdgUserDirs =
          lib.hm.dag.entryAfter [ "writeBoundary" ] (
            lib.concatMapStringsSep "\n"
              (d: "run mkdir -p ${lib.escapeShellArg d}")
              (lib.attrValues activeDirs)
          );
      })
    ];
}
