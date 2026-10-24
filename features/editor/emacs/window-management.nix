{ lib, mkFeature, mkElispConfig, ... }:

let
  inherit (lib) mkDefault mkOption types;

  windowType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to include this window.";
      };
      side = mkOption {
        type = types.enum [ "left" "right" "top" "bottom" ];
        description = "Frame side of the window.";
      };
      slot = mkOption {
        type = types.int;
        default = 0;
        description = "Position among windows on the same side; negative is left/above, positive right/below.";
      };
      size = mkOption {
        type = types.number;
        description = "Width (left/right) or height (top/bottom): a fraction of the frame, or columns/lines.";
      };
      names = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Regexps matched against buffer names.";
      };
      modes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Major modes; modes derived from them match too.";
      };
      key = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Key selecting this window in `dotty-window-management-map`.";
      };
    };
  };
in
mkFeature {
  name = [ "emacs" "window-management" ];

  options = {
    windows = mkOption {
      type = types.attrsOf windowType;
      default = { };
      description = "Side windows; the default of `dotty-window-management-windows`.";
    };
    focusSize = mkOption {
      type = types.number;
      default = 0.5;
      description = "Default of `dotty-window-management-focus-size`.";
    };
    key = mkOption {
      type = types.str;
      default = "w";
      description = "Key under `C-c` for `dotty-window-management-map`.";
    };
  };

  home = { config, lib, pkgs, ... }:
    let
      cfg = config.features.emacs.window-management;
      windows = lib.filterAttrs (_: w: w.enable) cfg.windows;
      toWindow = name: w: ''
        (${name} :side ${w.side} :slot ${toString w.slot} :size ${toString w.size}${
          lib.optionalString (w.key != null) " :key ${builtins.toJSON w.key}"}
         :buffers (${lib.concatStringsSep " " (map builtins.toJSON w.names ++ w.modes)}))'';
    in
    lib.mkMerge [
      {
        features.emacs.window-management.windows = {
          left = {
            key = mkDefault "h";
            side = mkDefault "left";
            size = mkDefault 0.2;
          };
          right = {
            key = mkDefault "l";
            side = mkDefault "right";
            size = mkDefault 0.3;
            names = [ "\\`\\*eldoc" ];
            modes = [ "help-mode" "Info-mode" "Man-mode" "woman-mode" "apropos-mode" "shortdoc-mode" ];
          };
          bottom-left = {
            key = mkDefault "j";
            side = mkDefault "bottom";
            slot = mkDefault (-1);
            size = mkDefault 0.3;
            modes = [ "comint-mode" "eshell-mode" "term-mode" ];
          };
          bottom-right = {
            key = mkDefault "k";
            side = mkDefault "bottom";
            slot = mkDefault 1;
            size = mkDefault 0.3;
            modes = [ "compilation-mode" ];
          };
        };
      }

      (mkElispConfig pkgs {
        name = "dotty-window-management";
        summary = "Predictable buffer display in side windows";
        manual = ./window-management.org;

        config = ''
          (require 'seq)

          (defgroup dotty-window-management nil
            "Predictable buffer display in side windows."
            :link '(info-link "(dotty-window-management)")
            :group 'dotty
            :prefix "dotty-window-management-")

          (defcustom dotty-window-management-windows
            '(${lib.concatStringsSep "\n" (lib.mapAttrsToList toWindow windows)})
            "Side windows and the buffers they house.
          Each element is (NAME . PLIST), NAME being a symbol.  PLIST keys:

            :side     `left', `right', `top' or `bottom'.
            :slot     Position among windows on the same side; negative is
                      left/above, positive right/below.
            :size     Width (left/right) or height (top/bottom): a fraction
                      of the frame, or a number of columns/lines.
            :buffers  A string is a regexp matched against buffer names, a
                      symbol a major mode (derived modes match too).
            :key      Key selecting the window in `dotty-window-management-map'."
            :type '(alist :key-type (symbol :tag "Name")
                          :value-type
                          (plist :options
                                 ((:side (choice (const left) (const right)
                                                 (const top) (const bottom)))
                                  (:slot integer)
                                  (:size number)
                                  (:buffers (repeat (choice (regexp :tag "Buffer name")
                                                            (symbol :tag "Major mode"))))
                                  (:key key))))
            :set (lambda (symbol value)
                   (set-default-toplevel-value symbol value)
                   (when (bound-and-true-p dotty-window-management-mode)
                     (dotty-window-management--install))))

          (defcustom dotty-window-management-focus-size ${toString cfg.focusSize}
            "Size of a focused side window, as a fraction of the frame.
          Width for left and right windows, height for top and bottom ones."
            :type 'number)

          (defvar-keymap dotty-window-management-map
            :doc "Keymap of window commands; window keys come from each window's `:key'.")

          (defvar-keymap dotty-window-management-cycle-map
            :doc "Keymap cycling the buffers of the side window behind each key.")

          (defvar-keymap dotty-window-management-focus-map
            :doc "Keymap focusing the side window behind each key.")

          (defvar-keymap dotty-window-management-fullscreen-map
            :doc "Keymap showing the side window behind each key in fullscreen.")

          (defconst dotty-window-management--main-rule
            '(dotty-window-management--same-window-p
              display-buffer-use-some-window
              (some-window . mru)
              (inhibit-same-window . t))
            "Rule showing buffers meant for a side window's own place in the main window.")

          (defvar dotty-window-management--rules nil
            "Entries `dotty-window-management-mode' added to `display-buffer-alist'.")

          (defun dotty-window-management--spec (name)
            "Return the plist of side window NAME."
            (or (alist-get name dotty-window-management-windows)
                (user-error "No side window named `%s'" name)))

          (defun dotty-window-management--condition (spec)
            "Return a `buffer-match-p' condition for the buffers of SPEC."
            `(or ,@(mapcar (lambda (b) (if (stringp b) b `(derived-mode . ,b)))
                           (plist-get spec :buffers))))

          (defun dotty-window-management--alist (spec &optional size)
            "Return the `display-buffer' action alist of SPEC, sized SIZE if non-nil."
            (let ((side (plist-get spec :side)))
              `((side . ,side)
                (slot . ,(or (plist-get spec :slot) 0))
                (,(if (memq side '(left right)) 'window-width 'window-height)
                 . ,(or size (plist-get spec :size)))
                (preserve-size . ,(if (memq side '(left right)) '(t . nil) '(nil . t))))))

          (defun dotty-window-management--window (spec)
            "Return the live side window of SPEC, if any."
            (seq-find (lambda (window)
                        (and (eq (window-parameter window 'window-side) (plist-get spec :side))
                             (eql (window-parameter window 'window-slot)
                                  (or (plist-get spec :slot) 0))))
                      (window-list nil 'nomini)))

          (defun dotty-window-management--buffers (spec)
            "Return the buffers belonging to SPEC, most recently used first."
            (let ((condition (dotty-window-management--condition spec)))
              (seq-filter (lambda (buffer)
                            (and (not (string-prefix-p " " (buffer-name buffer)))
                                 (buffer-match-p condition buffer)))
                          (buffer-list))))

          (defun dotty-window-management--buffer (spec)
            "Return the buffer shown in SPEC's window, else its most recent one."
            (let ((window (dotty-window-management--window spec)))
              (or (and window (window-buffer window))
                  (car (dotty-window-management--buffers spec))
                  (user-error "No buffers for this side window"))))

          (defun dotty-window-management--show (spec buffer &optional size)
            "Display BUFFER in the side window of SPEC and return that window."
            (let ((display-buffer-overriding-action
                   (cons #'display-buffer-in-side-window
                         (dotty-window-management--alist spec size))))
              (display-buffer buffer)))

          (defun dotty-window-management--same-window-p (_buffer &optional action)
            "Non-nil if ACTION wants the selected window and that is a side window."
            (and (window-parameter nil 'window-side)
                 (memq #'display-buffer-same-window (ensure-list (car action)))))

          (defun dotty-window-management--delete-side-windows ()
            "Delete all side windows of the selected frame."
            (dolist (window (window-list nil 'nomini))
              (when (window-parameter window 'window-side)
                (delete-window window))))

          (defun dotty-window-management--save (command name)
            "Remember the layout before COMMAND changed it for window NAME."
            (set-frame-parameter nil 'dotty-window-management--state
                                 (list command name (current-window-configuration))))

          (defun dotty-window-management--restore (command name)
            "Restore the layout saved by `dotty-window-management--save'.
          Return non-nil if COMMAND for window NAME saved it."
            (pcase (frame-parameter nil 'dotty-window-management--state)
              (`(,saved-command ,saved-name ,configuration)
               (set-frame-parameter nil 'dotty-window-management--state nil)
               (set-window-configuration configuration)
               (and (eq saved-command command) (eq saved-name name)))))

          (defun dotty-window-management--name (window)
            "Return the name of the side window WINDOW is, if any."
            (car (seq-find (lambda (entry)
                             (eq (dotty-window-management--window (cdr entry)) window))
                           dotty-window-management-windows)))

          (defun dotty-window-management--read ()
            "Read a side window name, defaulting to the selected one."
            (let ((default (dotty-window-management--name (selected-window))))
              (intern (completing-read
                       (format-prompt "Side window" default)
                       (mapcar (lambda (entry) (symbol-name (car entry)))
                               dotty-window-management-windows)
                       nil t nil nil (and default (symbol-name default))))))

          (defun dotty-window-management-cycle (name)
            "Show the next buffer of side window NAME, showing the window if hidden."
            (interactive (list (dotty-window-management--read)))
            (let* ((spec (dotty-window-management--spec name))
                   (window (dotty-window-management--window spec))
                   (buffers (sort (dotty-window-management--buffers spec)
                                  (lambda (a b) (string< (buffer-name a) (buffer-name b))))))
              (unless buffers
                (user-error "No buffers for side window `%s'" name))
              (dotty-window-management--show
               spec (if window
                        (or (cadr (memq (window-buffer window) buffers)) (car buffers))
                      (dotty-window-management--buffer spec)))))

          (defun dotty-window-management-toggle (name)
            "Show or hide side window NAME."
            (interactive (list (dotty-window-management--read)))
            (let* ((spec (dotty-window-management--spec name))
                   (window (dotty-window-management--window spec)))
              (if window
                  (delete-window window)
                (dotty-window-management--show spec (dotty-window-management--buffer spec)))))

          (defun dotty-window-management-toggle-all ()
            "Hide all side windows if any is shown, otherwise show all of them.
          Windows without buffers stay hidden."
            (interactive)
            (let ((specs (mapcar #'cdr dotty-window-management-windows)))
              (if-let* ((windows (delq nil (mapcar #'dotty-window-management--window specs))))
                  (mapc #'delete-window windows)
                (or (seq-filter #'identity
                                (mapcar (lambda (spec)
                                          (when-let* ((buffer (car (dotty-window-management--buffers spec))))
                                            (dotty-window-management--show spec buffer)))
                                        specs))
                    (user-error "No side window has buffers to show")))))

          (defun dotty-window-management-focus (name)
            "Show only side window NAME, sized `dotty-window-management-focus-size'.
          Call again to restore the previous layout."
            (interactive (list (dotty-window-management--read)))
            (unless (dotty-window-management--restore 'focus name)
              (let* ((spec (dotty-window-management--spec name))
                     (buffer (dotty-window-management--buffer spec)))
                (dotty-window-management--save 'focus name)
                (dotty-window-management--delete-side-windows)
                (select-window (dotty-window-management--show
                                spec buffer dotty-window-management-focus-size)))))

          (defun dotty-window-management-fullscreen (name)
            "Show the buffer of side window NAME as the only window.
          Call again to restore the previous layout."
            (interactive (list (dotty-window-management--read)))
            (unless (dotty-window-management--restore 'fullscreen name)
              (let ((buffer (dotty-window-management--buffer
                             (dotty-window-management--spec name))))
                (dotty-window-management--save 'fullscreen name)
                (dotty-window-management--delete-side-windows)
                (delete-other-windows)
                (set-window-dedicated-p nil nil)
                (set-window-buffer nil buffer))))

          (defun dotty-window-management--define-commands ()
            "Define `dotty-window-management-NAME-COMMAND' for every side window."
            (dolist (entry dotty-window-management-windows)
              (dolist (command '(cycle toggle focus fullscreen))
                (let ((name (car entry))
                      (fn (intern (format "dotty-window-management-%s" command))))
                  (defalias (intern (format "dotty-window-management-%s-%s" name command))
                    (lambda () (interactive) (funcall fn name))
                    (format "Call `%s' on side window `%s'." fn name))))))

          (defun dotty-window-management--define-keys ()
            "Rebuild `dotty-window-management-map' from the windows' `:key'."
            (let ((maps `((toggle . ,dotty-window-management-map)
                          (cycle . ,dotty-window-management-cycle-map)
                          (focus . ,dotty-window-management-focus-map)
                          (fullscreen . ,dotty-window-management-fullscreen-map))))
              (dolist (map maps) (setcdr (cdr map) nil))
              (keymap-set dotty-window-management-map "w" #'dotty-window-management-toggle-all)
              (keymap-set dotty-window-management-map "c" (cons "cycle" dotty-window-management-cycle-map))
              (keymap-set dotty-window-management-map "f" (cons "focus" dotty-window-management-focus-map))
              (keymap-set dotty-window-management-map "F" (cons "fullscreen" dotty-window-management-fullscreen-map))
              (dolist (entry dotty-window-management-windows)
                (when-let* ((key (plist-get (cdr entry) :key)))
                  (pcase-dolist (`(,command . ,map) maps)
                    (keymap-set map key
                                (cons (symbol-name (car entry))
                                      (intern (format "dotty-window-management-%s-%s"
                                                      (car entry) command)))))
                  (put (intern (format "dotty-window-management-%s-cycle" (car entry)))
                       'repeat-map 'dotty-window-management-cycle-map)))))

          (defun dotty-window-management--uninstall ()
            "Remove the rules added by `dotty-window-management--install'."
            (setq display-buffer-alist
                  (seq-difference display-buffer-alist dotty-window-management--rules #'eq)
                  dotty-window-management--rules nil))

          (defun dotty-window-management--install ()
            "Add the side window rules to `display-buffer-alist'."
            (dotty-window-management--uninstall)
            (setq dotty-window-management--rules
                  (append (mapcar (lambda (entry)
                                    (cons (dotty-window-management--condition (cdr entry))
                                          (cons #'display-buffer-in-side-window
                                                (dotty-window-management--alist (cdr entry)))))
                                  dotty-window-management-windows)
                          (list dotty-window-management--main-rule))
                  display-buffer-alist
                  (append dotty-window-management--rules display-buffer-alist))
            (dotty-window-management--define-commands)
            (dotty-window-management--define-keys))

          ;;;###autoload
          (define-minor-mode dotty-window-management-mode
            "Display buffers in the side windows of `dotty-window-management-windows'."
            :global t
            (if dotty-window-management-mode
                (dotty-window-management--install)
              (dotty-window-management--uninstall)))
        '';
      })

      {
        programs.emacs.extraConfig = ''
          (setopt window-sides-vertical t
                  switch-to-buffer-obey-display-actions t)
          (dotty-window-management-mode 1)
          (with-eval-after-load 'dotty-keymaps
            (keymap-set mode-specific-map "${cfg.key}" (cons "Windows" dotty-window-management-map)))
        '';
      }
    ];
}
