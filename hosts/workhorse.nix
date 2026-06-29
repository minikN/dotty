{
  system = "aarch64-darwin";

  features = {
    font.enable = true;
    theme.enable = true;
    ghostty.enable = true;
    ssh.enable = true;
    gnupg = {
      enable = true;
      sshKeys = [ "E3FFA5A1B444A4F099E594758008C1D8845EC7C0" ];
    };
    zsh = {
      enable = true;
      extraConfig = ''
        export PATH="/opt/homebrew/bin:$PATH"
      '';
    };
  };
}
