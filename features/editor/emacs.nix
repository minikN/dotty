{ lib, mkFeature, mkElispConfig, ... }:

let
  inherit (lib) mkOption optionalString types;
in
mkFeature {
  name = "emacs";

  options = { config, pkgs, ... }: {
    package = mkOption {
      type = types.package;
      default = if config.globals.wayland then pkgs.emacs-pgtk else pkgs.emacs;
      defaultText = lib.literalExpression "pkgs.emacs-pgtk on Wayland, pkgs.emacs otherwise";
      description = "Emacs package.";
    };

    earlyInit = mkOption {
      type = types.lines;
      default = "";
      description = "early-init.el contents; features contribute via mkElispConfig's `earlyInit`.";
    };
  };

  globals = { config, ... }: {
    apps.editor = lib.mkIf config.features.emacs.enable
      "${config.features.emacs.package}/bin/emacsclient -c";
  };

  home = { config, lib, pkgs, ... }:
    let
      cfg = config.features.emacs;
      inherit (config.features) font user;
      shell = config.globals.apps.shell;
      stateDir = "${config.xdg.stateHome}/emacs";
      isDarwin = config.globals.platform == "darwin";
      shellEnvVars = [ "PATH" "MANPATH" "SSH_AUTH_SOCK" "NIX_SSL_CERT_FILE" ]
        ++ builtins.attrNames config.home.sessionVariables;
    in
    lib.mkMerge [
      {
        programs.emacs = {
          enable = true;
          package = cfg.package;
        };

        ## Daemon via systemd (NixOS) or launchd (darwin); apps.editor attaches to it.
        services.emacs = {
          enable = true;
          client.enable = true;
        };

        xdg.configFile."emacs/early-init.el".text = ''
          ;;; early-init.el -*- lexical-binding: t -*-
          ${cfg.earlyInit}
        '';

        ## Emacs won't create these itself; not done in elisp since the config
        ## is also loaded at build time (byte-compiling default.el).
        home.activation.createEmacsStateDirs =
          lib.hm.dag.entryAfter [ "writeBoundary" ]
            "run mkdir -p ${lib.escapeShellArg "${stateDir}/auto-save"} ${lib.escapeShellArg "${stateDir}/lock"}";
      }

      (mkElispConfig pkgs {
        name = "dotty-emacs";
        summary = "Base Emacs configuration";
        elispPackages = epkgs: [ epkgs.wgrep ]
          ++ lib.optional isDarwin epkgs.exec-path-from-shell;

        earlyInit = ''
          ;; Defer GC while starting up; restore a sane threshold afterwards.
          (setq gc-cons-threshold most-positive-fixnum
                gc-cons-percentage 0.6)
          (add-hook 'emacs-startup-hook
                    (lambda ()
                      (setq gc-cons-threshold (* 16 1024 1024)
                            gc-cons-percentage 0.1)))
          ;; Packages are native-compiled ahead of time by nix.
          (setq native-comp-jit-compilation nil)
          (advice-add 'x-apply-session-resources :override #'ignore)
          ;; No GUI chrome or splash; set as frame params so it never flashes.
          (push '(menu-bar-lines . 0) default-frame-alist)
          (push '(tool-bar-lines . 0) default-frame-alist)
          (push '(vertical-scroll-bars) default-frame-alist)
          (push '(horizontal-scroll-bars) default-frame-alist)
          (setq menu-bar-mode nil
                tool-bar-mode nil
                scroll-bar-mode nil
                inhibit-startup-screen t
                initial-scratch-message nil)
          ${optionalString font.enable ''
            (push '(font . "${font.fonts.monospace.name}-${toString font.fonts.monospace.size}")
                  default-frame-alist)
          ''}
        '';

        config = ''
          (setq user-full-name "${user.fullName}"
                user-mail-address "${user.email}")

          ;; Persistent state goes to XDG_STATE_HOME, not the config dir.
          (setopt custom-file "${stateDir}/custom.el")
          (load custom-file t)
          (setopt backup-directory-alist '(("." . "${stateDir}/backup"))
                  bookmark-default-file "${stateDir}/bookmarks"
                  save-place-file "${stateDir}/places"
                  recentf-save-file "${stateDir}/recentf"
                  savehist-file "${stateDir}/history"
                  auto-save-list-file-prefix "${stateDir}/auto-save/.saves-")
          (setq auto-save-file-name-transforms '((".*" "${stateDir}/auto-save/" t))
                lock-file-name-transforms '((".*" "${stateDir}/lock/" t)))

          (save-place-mode 1)
          (recentf-mode 1)
          (run-with-idle-timer 30 t #'recentf-save-list)
          (setopt history-length 10000)
          (savehist-mode 1)

          (setopt warning-minimum-level :error
                  undo-limit (* 8 1024 1024)
                  read-process-output-max (* 1024 1024)
                  save-interprogram-paste-before-kill t
                  mouse-yank-at-point t
                  require-final-newline t
                  what-cursor-show-names t
                  scroll-conservatively 100
                  global-auto-revert-non-file-buffers t)
          (setq-default indent-tabs-mode nil)
          (global-subword-mode 1)
          (global-auto-revert-mode 1)
          (repeat-mode 1)
          (pixel-scroll-precision-mode 1)

          (setopt copyright-names-regexp
                  (regexp-quote (format "%s <%s>" user-full-name user-mail-address)))
          (add-hook 'before-save-hook #'copyright-update)
          (add-hook 'before-save-hook #'delete-trailing-whitespace)

          (keymap-global-set "M-K" #'kill-whole-line)
          (keymap-global-set "M-c" #'capitalize-dwim)
          (keymap-global-set "M-l" #'downcase-dwim)
          (keymap-global-set "M-u" #'upcase-dwim)

          (with-eval-after-load 'mwheel
            (setopt mouse-wheel-scroll-amount '(1 ((shift) . 1) ((control) . 1))
                    mouse-wheel-progressive-speed nil
                    mouse-wheel-follow-mouse t))

          ${optionalString (shell != null) ''
            (setopt explicit-shell-file-name "${shell}")
          ''}
          ${optionalString font.enable ''
            (defun dotty-emacs--set-emoji-font ()
              (when (display-graphic-p)
                (set-fontset-font t 'emoji (font-spec :family "${font.fonts.unicode.name}"))))
            (dotty-emacs--set-emoji-font)
            (add-hook 'server-after-make-frame-hook #'dotty-emacs--set-emoji-font)
          ''}
          ${optionalString isDarwin ''
            (require 'exec-path-from-shell)
            ${optionalString (shell != null) ''
              (setopt exec-path-from-shell-shell-name "${shell}")
            ''}
            (setopt exec-path-from-shell-variables
                    '(${lib.concatMapStringsSep " " (v: ''"${v}"'') shellEnvVars}))
            (unless noninteractive
              (exec-path-from-shell-initialize))
          ''}
        '';
      })
    ];
}
