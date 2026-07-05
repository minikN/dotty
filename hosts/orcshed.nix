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

    nixarr = {
      enable = true;
      sabnzbd = true;
      prowlarr = true;
      sonarr = true;
      radarr = true;
      mediaGroups = [ "users" ];
      wgConf = config.age.secrets."wg-1.conf".path;
    };
  };

  nixos = { config, inputs, pkgs, ... }:
    {
    imports = [
      inputs.nixos-hardware.nixosModules.common-cpu-intel
      inputs.nixos-hardware.nixosModules.common-pc-ssd
      inputs.agenix.nixosModules.default
    ];

    networking.hostName = "orcshed";

    age.secrets = {
      smb-credentials = {
        file = ../secrets/smb-credentials.age;
        owner = "root";
        group = "root";
        mode = "0600";
      };
      "wg-1.conf" = {
        file = ../secrets/wg-1.conf.age;
        owner = "root";
        group = "root";
        mode = "0600";
      };
      "wg-2.conf" = {
        file = ../secrets/wg-2.conf.age;
        owner = "root";
        group = "root";
        mode = "0600";
      };
      "wg-3.conf" = {
        file = ../secrets/wg-3.conf.age;
        owner = "root";
        group = "root";
        mode = "0600";
      };
      "sabnzbd-creds" = {
        file = ../secrets/sabnzbd-creds.age;
        owner = "sabnzbd";
        group = "media";
        mode = "0400";
      };
      "prowlarr-indexer-key" = {
        file = ../secrets/prowlarr-indexer-key.age;
        owner = "prowlarr";
        group = "prowlarr";
        mode = "0400";
      };
      "sabnzbd-api-key" = {
        file = ../secrets/sabnzbd-api-key.age;
        owner = "root";
        group = "media";
        mode = "0440";
      };
    };

    services.sabnzbd.settings.servers.usenet = {
      name = "usenet";
      displayname = "Usenet";
      host = "news.eweka.nl";
      port = 563;
      ssl = true;
      connections = 20;
    };
    services.sabnzbd.secretFiles = [ config.age.secrets."sabnzbd-creds".path ];

    nixarr.prowlarr.settings-sync.indexers = [
      {
        sort_name = "generic newznab";
        name = "treasure-maps";
        fields = {
          baseUrl = "https://treasure-maps.com";
          apiPath = "/api";
          apiKey.secret = config.age.secrets."prowlarr-indexer-key".path;
        };
      }
    ];


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
