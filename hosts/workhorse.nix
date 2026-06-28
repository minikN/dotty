{
  system = "aarch64-darwin";

  features = {
    zsh = {
      enable = true;
      extraConfig = ''
        export PATH="$HOME/.local/bin:$PATH"
        export PATH="/opt/homebrew/bin:$PATH"
      '';
    };
  };
}
