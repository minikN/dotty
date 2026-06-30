{
  system = "x86_64-linux";

  features = {
    zsh.enable = true;
    nas.enable = true;

    ssh = {
      enable = true;
      daemon = {
        enable = true;
        passwordAuthentication = false;
      };
      authorizedKeyFiles = [ ../keys/db.pub ];
    };

    caddy = {
      enable = true;
      vhosts."jellyfin.minikn.xyz".backend = "http://127.0.0.1:8096";
      vhosts."books.minikn.xyz".backend = "http://127.0.0.1:8000";
    };

    fail2ban.enable = true;

    audiobookshelf = {
      enable = true;
      host = "127.0.0.1";
      openFirewall = false;
      mediaGroups = [ "users" ];
    };

    jellyfin = {
      enable = true;
      openFirewall = false;
      mediaGroups = [ "users" ];
    };
  };

  nixos = { config, inputs, pkgs, ... }: {
    imports = [
      inputs.nixos-hardware.nixosModules.common-cpu-intel
      inputs.nixos-hardware.nixosModules.common-pc-ssd
      inputs.agenix.nixosModules.default
    ];

    age.secrets.smb-credentials = {
      file = ../secrets/smb-credentials.age;
      owner = "root";
      group = "root";
      mode = "0600";
    };

    features.nas.credentialsFile = config.age.secrets.smb-credentials.path;

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
