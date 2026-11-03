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
      host = "0.0.0.0";
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
      models = {
        "Qwen3.6-35B-A3B" = {
          hfRepo = "unsloth/Qwen3.6-35B-A3B-GGUF";
          hfFile = "Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
          loadOnStartup = true;
        };
        "Mellum2.1-12B-A2.5B" = {
          hfRepo = "JetBrains/Mellum2.1-12B-A2.5B-Thinking-GGUF";
          hfFile = "Mellum2.1-12B-A2.5B-Thinking-MXFP4_MOE.gguf";
        };
        "Nemotron3.5-Lightning" = {
          hfRepo = "ggml-org/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF";
          hfFile = "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-Q4_0.gguf";
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
