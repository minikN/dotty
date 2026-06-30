{ lib, mkFeature, ... }:

mkFeature {
  name = "sway";

  options = { config, pkgs, ... }:
    let
      inherit (lib) mkEnableOption mkOption mkPackageOption types;
    in
    {
      package = mkPackageOption pkgs "sway" { };

      modifier = mkOption {
        type = types.str;
        default = "Mod4";
        description = "Sway modifier key (Mod4 = Super/Cmd).";
      };

      left = mkOption {
        type = types.str;
        default = "h";
        description = "Key bound to the `left` direction.";
      };
      right = mkOption {
        type = types.str;
        default = "l";
        description = "Key bound to the `right` direction.";
      };
      up = mkOption {
        type = types.str;
        default = "k";
        description = "Key bound to the `up` direction.";
      };
      down = mkOption {
        type = types.str;
        default = "j";
        description = "Key bound to the `down` direction.";
      };

      useGlobalBar = mkEnableOption ''
        having sway spawn and supervise the global bar (vs. running the
        bar as a standalone user systemd service)'';

      extraGlobalBarSettings = mkOption {
        type = types.attrs;
        default = { };
        description = "Extra fields merged into sway's `bar` block when `useGlobalBar = true`.";
      };

      extraKeybindings = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = ''
          Extra Sway keybindings. Use `config.features.sway.modifier`
          and friends to compose key combos that respect the configured
          modifier/direction keys.
        '';
      };

      extraConfig = mkOption {
        type = types.attrs;
        default = { };
        description = ''
          Extra fields recursively merged into the generated sway
          config attrset (overrides existing keys).
        '';
      };
    };

  globals = { config, ... }:
    let
      cfg = config.features.sway;
    in
    lib.mkIf cfg.enable {
      apps.wm = lib.mkForce "${cfg.package}/bin/sway";
      wayland = lib.mkForce true;
      wmControlledBar = lib.mkForce cfg.useGlobalBar;
    };

  nixos = _: {
    hardware.graphics.enable = true;
    security.polkit.enable = true;
    ## Tell Chromium/Electron apps to use native Wayland windows.
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };

  home = { config, lib, pkgs, ... }:
    let
      cfg = config.features.sway;
      apps = config.globals.apps;
      hex = config.features.theme.scheme.withHashtag;
      kbd = config.features.keyboard.layout;
      cursor = config.features.gtk.cursorTheme;
    in
    {
      programs.swayr = {
        enable = true;
        systemd.enable = true;
      };

      home.packages = with pkgs; [ wl-clipboard wtype ];

      wayland.windowManager.sway = {
        enable = true;
        inherit (cfg) package;
        systemd.enable = true;
        xwayland = true;
        wrapperFeatures = {
          base = true;
          gtk = true;
        };

        extraSessionCommands = ''
          export QT_QPA_PLATFORM=wayland
          export XDG_SESSION_TYPE=wayland
          export XDG_CURRENT_DESKTOP=sway
          export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
          export SDL_VIDEODRIVER=wayland
          export _JAVA_AWT_WM_NONREPARENTING=1
        '';

        config = lib.recursiveUpdate
          {
            inherit (cfg) modifier left right up down;
            defaultWorkspace = "workspace number 1";

            input = {
              "type:keyboard" = {
                xkb_layout = kbd.name;
                xkb_options = lib.concatStringsSep "," kbd.options;
              }
              // lib.optionalAttrs (kbd.variant != "") {
                xkb_variant = kbd.variant;
              };
              "type:touchpad" = {
                dwt = "enabled";
                tap = "enabled";
                middle_emulation = "enabled";
              };
            };

            output."*".bg =
              if config.features.theme.wallpaper == null
              then "${hex.base00} solid_color"
              else "${toString config.features.theme.wallpaper} fill";

            seat."*".xcursor_theme = "${cursor.name} ${toString config.features.gtk.cursorSize}";

            floating = {
              titlebar = false;
              border = 2;
            };

            ## Note: ordenada brightens/darkens base0D for the focused
            ## tint via nix-rice. We don't have nix-rice; use base0D
            ## directly. Slightly less polished but still legible.
            colors =
              let
                bg = hex.base00;
                focused = hex.base0D;
                unfocused = hex.base01;
                text = hex.base05;
                urgent = hex.base08;
                shared = {
                  background = bg;
                  indicator = focused;
                  inherit text;
                };
              in
              {
                background = bg;
                urgent = shared // { border = urgent; childBorder = urgent; };
                focused = shared // { border = focused; childBorder = focused; };
                focusedInactive = shared // { border = unfocused; childBorder = unfocused; };
                unfocused = shared // { border = unfocused; childBorder = unfocused; };
                placeholder = shared // { border = unfocused; childBorder = unfocused; };
              };

            window = {
              titlebar = false;
              border = 2;
            };

            gaps = {
              inner = 12;
              smartBorders = "on";
              smartGaps = true;
            };

            bars = lib.optional cfg.useGlobalBar (
              {
                command = apps.bar;
                mode = "dock";
                extraConfig = "modifier none";
              }
              // cfg.extraGlobalBarSettings
            );

            startup = map (command: { inherit command; always = true; })
              config.globals.autoloads;

            keybindings = lib.mkOptionDefault (
              { }
              // lib.optionalAttrs (apps.launcher != null) {
                "${cfg.modifier}+d" = "exec ${apps.launcher}";
              }
              // lib.optionalAttrs (apps.terminal != null) {
                "${cfg.modifier}+Return" = "exec ${apps.terminal}";
              }
              // lib.optionalAttrs (apps.passwordManager != null) {
                "${cfg.modifier}+p" = "exec ${apps.passwordManager}";
              }
              // lib.optionalAttrs cfg.useGlobalBar {
                "${cfg.modifier}+b" = "bar mode toggle";
              }
              // cfg.extraKeybindings
            );
          }
          cfg.extraConfig;
      };
    };
}
