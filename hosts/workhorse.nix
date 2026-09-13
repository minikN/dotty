{
  system = "aarch64-darwin";

  features = {
    font.enable = true;
    theme.enable = true;
    aerospace.enable = true;
    choose-gui.enable = true;
    ghostty.enable = true;
    zmk.enable = true;
    ssh.enable = true;
    password-store.enable = true;
    gnupg = {
      enable = true;
      keychainInteraction = false;
      sshKeys = [ "E3FFA5A1B444A4F099E594758008C1D8845EC7C0" ];
    };
    zsh = {
      enable = true;
      extraConfig = ''
        export PATH="/opt/homebrew/bin:$PATH"
        export PATH="/opt/homebrew/opt/ruby@3.4/bin:$PATH"
        export LDFLAGS="-L/opt/homebrew/opt/ruby@3.4/lib"
        export CPPFLAGS="-I/opt/homebrew/opt/ruby@3.4/include"
        export PKG_CONFIG_PATH="/opt/homebrew/opt/ruby@3.4/lib/pkgconfig"
      '';
    };
  };
}
