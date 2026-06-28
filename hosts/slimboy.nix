{
  system = "x86_64-linux";

  features = {
    zsh = {
      enable = true;
      extraConfig = ''
        export PATH="$HOME/.local/bin:$PATH"
      '';
    };
  };

  nixos = { pkgs, ... }: {
    networking.hostName = "slimboy";
    networking.interfaces.wlp4s0.useDHCP = true;

    boot.kernelModules = [ "kvm-intel" ];
    boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_latest;

    hardware.enableRedistributableFirmware = true;
    hardware.cpu.intel.updateMicrocode = true;
  };
}
