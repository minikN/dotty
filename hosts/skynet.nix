{
  system = "x86_64-linux";
  hardware = [ "common-cpu-intel" "common-pc-ssd" ];

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
      backend = "vulkan"; # RX 6650 XT (gfx1032) via Mesa RADV
      openFirewall = true;
      environment.GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM = "1";
      models.qwen = {
        hfRepo = "unsloth/Qwen3.6-35B-A3B-GGUF";
        hfFile = "Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";

        host = "0.0.0.0";
        port = 8080;
        settings = {
          ctx-size = 131072;
          cache-type-k = "q8_0";
          cache-type-v = "q8_0";
          no-mmproj = true;
          fit-target = 256;
          ubatch-size = 2048;
          #moe-cache-mib = 2048;
          #load-mode = "none";
        };
      };
    };
  };

  nixos = { config, inputs, pkgs, ... }:
    {
    imports = [
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
