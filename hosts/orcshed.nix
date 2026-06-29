{
  system = "x86_64-linux";

  features = {
    zsh.enable = true;

    ssh = {
      enable = true;
      daemon = {
        enable = true;
        passwordAuthentication = false;
      };
      authorizedKeyFiles = [ ../keys/db.pub ];
    };
  };

  nixos = { inputs, pkgs, ... }: {
    imports = [
      inputs.nixos-hardware.nixosModules.common-cpu-intel
      inputs.nixos-hardware.nixosModules.common-pc-ssd
    ];

    networking.hostName = "orcshed";

    boot.kernelModules = [ "kvm-intel" ];
    boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_latest;
    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];

    hardware.enableRedistributableFirmware = true;
  };
}
