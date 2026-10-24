{ lib, mkFeature, mkElispConfig, ... }:

mkFeature {
  name = [ "emacs" "completion" ];

  home = { pkgs, ... }: mkElispConfig pkgs {
    name = "dotty-completion";
    summary = "Completion with Vertico, Orderless, Marginalia, Consult and Embark";
    elispPackages = epkgs: with epkgs; [
      vertico
      orderless
      marginalia
      consult
      embark
      embark-consult
    ];

    config = ''
      (eval-when-compile (require 'consult))
      (declare-function consult--customize-put "consult")

      ;; Vertico: vertical completion UI, also for `completion-at-point'.
      (setopt enable-recursive-minibuffers t
              read-extended-command-predicate #'command-completion-default-include-p
              minibuffer-prompt-properties
              '(read-only t cursor-intangible t face minibuffer-prompt))
      (setq completion-in-region-function #'consult-completion-in-region)
      (vertico-mode 1)

      ;; Orderless: space-separated components, matched in any order.
      (setopt completion-styles '(orderless basic)
              completion-category-defaults nil
              completion-category-overrides '((file (styles partial-completion)))
              completion-pcm-leading-wildcard t)

      ;; Marginalia: annotations next to candidates.
      (marginalia-mode 1)
      (keymap-set minibuffer-local-map "M-A" #'marginalia-cycle)

      ;; Consult: replace built-in commands at their usual keys.
      (keymap-global-set "<remap> <switch-to-buffer>" #'consult-buffer)
      (keymap-global-set "<remap> <switch-to-buffer-other-window>" #'consult-buffer-other-window)
      (keymap-global-set "<remap> <switch-to-buffer-other-frame>" #'consult-buffer-other-frame)
      (keymap-global-set "<remap> <switch-to-buffer-other-tab>" #'consult-buffer-other-tab)
      (keymap-global-set "<remap> <project-switch-to-buffer>" #'consult-project-buffer)
      (keymap-global-set "<remap> <bookmark-jump>" #'consult-bookmark)
      (keymap-global-set "<remap> <yank-pop>" #'consult-yank-pop)
      (keymap-global-set "<remap> <goto-line>" #'consult-goto-line)
      (keymap-global-set "<remap> <imenu>" #'consult-imenu)
      (keymap-global-set "<remap> <repeat-complex-command>" #'consult-complex-command)
      (keymap-global-set "<remap> <Info-search>" #'consult-info)
      (keymap-set isearch-mode-map "<remap> <isearch-edit-string>" #'consult-isearch-history)
      (keymap-set minibuffer-local-map "<remap> <next-matching-history-element>" #'consult-history)
      (keymap-set minibuffer-local-map "<remap> <previous-matching-history-element>" #'consult-history)

      ;; Consult: further commands in the built-in `M-g' and `M-s' maps.
      (keymap-set goto-map "e" #'consult-compile-error)
      (keymap-set goto-map "r" #'consult-grep-match)
      (keymap-set goto-map "f" #'consult-flymake)
      (keymap-set goto-map "o" #'consult-outline)
      (keymap-set goto-map "m" #'consult-mark)
      (keymap-set goto-map "k" #'consult-global-mark)
      (keymap-set goto-map "I" #'consult-imenu-multi)
      (keymap-set search-map "d" #'consult-find)
      (keymap-set search-map "g" #'consult-grep)
      (keymap-set search-map "G" #'consult-git-grep)
      (keymap-set search-map "r" #'consult-ripgrep)
      (keymap-set search-map "l" #'consult-line)
      (keymap-set search-map "L" #'consult-line-multi)
      (keymap-set search-map "k" #'consult-keep-lines)
      (keymap-set search-map "u" #'consult-focus-lines)
      (keymap-set search-map "e" #'consult-isearch-history)
      (keymap-set isearch-mode-map "M-s l" #'consult-line)
      (keymap-set isearch-mode-map "M-s L" #'consult-line-multi)

      ;; Consult: registers and xref with preview.
      (advice-add #'register-preview :override #'consult-register-window)
      (setopt register-preview-delay 0.5
              xref-show-xrefs-function #'consult-xref
              xref-show-definitions-function #'consult-xref)

      (with-eval-after-load 'consult
        (setopt consult-narrow-key "<"
                consult-ripgrep-args
                (replace-regexp-in-string "\\`rg\\b" "${pkgs.ripgrep}/bin/rg" consult-ripgrep-args))
        (consult-customize
         consult-ripgrep consult-git-grep consult-grep consult-man
         consult-bookmark consult-recent-file consult-xref
         consult-source-bookmark consult-source-file-register
         consult-source-recent-file consult-source-project-recent-file
         :preview-key '(:debounce 0.4 any)))

      ;; Embark: act on the candidate or thing at point.
      (keymap-global-set "C-." #'embark-act)
      (keymap-global-set "C-;" #'embark-dwim)
      (keymap-set help-map "B" #'embark-bindings)
      (setq prefix-help-command #'embark-prefix-help-command)
    '';
  };
}
