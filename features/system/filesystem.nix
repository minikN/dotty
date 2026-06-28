{ lib, mkFeature, ... }:

mkFeature {
  name = "filesystem";
  enableByDefault = true;

  nixos = { ... }: {
    fileSystems."/" = {
      device = "/dev/disk/by-label/SYSTEM";
      fsType = "btrfs";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
    };

    swapDevices = [
      { device = "/dev/disk/by-label/SWAP"; }
    ];
  };
}
