{
  system = "x86_64-linux";

  features = {
    home.autoStartWmOnTty = "/dev/tty1";
    sway.enable = true;
    gtk.enable = true;
    theme.enable = true;
    keyboard.enable = true;
    font.enable = true;
    ghostty.enable = true;

    gnupg = {
      enable = true;
      sshKeys = [ "E3FFA5A1B444A4F099E594758008C1D8845EC7C0" ];
    };

    ssh = {
      enable = true;
      daemon = {
        enable = true;
        passwordAuthentication = false;
      };
      authorizedKeyFiles = [ ../keys/db.pub ];
    };

    zsh = {
      enable = true;
      extraConfig = ''
        export PATH="$HOME/.local/bin:$PATH"
      '';
    };
  };

  nixos = { pkgs, inputs, ... }: {
    imports = [
       inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460
    ];
    networking.hostName = "slimboy";
    #networking.interfaces.wlp4s0.useDHCP = true;

    boot.kernelModules = [ "kvm-intel" ];
    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];
    boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_latest;

    hardware.enableRedistributableFirmware = true;
    hardware.cpu.intel.updateMicrocode = true;
  };
}
