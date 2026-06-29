{
  system = "aarch64-darwin";

  features = {
    font.enable = true;
    theme.enable = true;
    ghostty.enable = true;
    zsh = {
      enable = true;
      extraConfig = ''
        export PATH="/opt/homebrew/bin:$PATH"
      '';
    };
  };
}
