{
  system = "x86_64-linux";

  features = { config, ... }: {
    zsh.enable = true;
    nas = {
      enable = true;
      credentialsFile = config.age.secrets.smb-credentials.path;
    };

    ssh = {
      enable = true;
      daemon = {
        enable = true;
        passwordAuthentication = false;
      };
      authorizedKeyFiles = [ ../keys/db.pub ];
    };

    llama-cpp = {
      enable = true;
      backend = "vulkan";        # RX 6650 XT (gfx1032) via Mesa RADV
      openFirewall = true;
      models.qwen = {
        hfRepo = "unsloth/Qwen3.5-35B-A3B-GGUF";
        quant = "Q4_K_M";

        host = "0.0.0.0";        # reachable on the LAN
        port = 8080;
        settings = {
        };
      };
    };
  };

  nixos = { config, inputs, pkgs, ... }:
    {
    imports = [
      inputs.nixos-hardware.nixosModules.common-cpu-intel
      inputs.nixos-hardware.nixosModules.common-pc-ssd
      inputs.agenix.nixosModules.default
    ];

    networking.hostName = "skynet";

    age.secrets = {
      smb-credentials = {
        file = ../secrets/smb-credentials.age;
        owner = "root";
        group = "root";
        mode = "0600";
      };
    };

    boot.kernelModules = [ "kvm-intel" ];
    boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_latest;
    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];

    environment.systemPackages = [
      config.features.llama-cpp.package
      pkgs.radeontop
    ];

    hardware = {
      enableRedistributableFirmware = true;
      graphics = {
        enable = true;
        extraPackages = [
          pkgs.rocmPackages.clr.icd
        ];
      };
    };
  };
}
