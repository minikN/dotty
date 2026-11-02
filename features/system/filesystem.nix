{ lib, mkFeature, ... }:

mkFeature {
  name = "filesystem";
  enableByDefault = true;

  nixos = { ... }: {
    fileSystems."/" = {
      device = "/dev/disk/by-label/SYSTEM";
      fsType = "btrfs";
    };

    boot.loader.efi.efiSysMountPoint = "/boot/efi";
    fileSystems."/boot/efi" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
    };

    swapDevices = [
      { device = "/dev/disk/by-label/SWAP"; }
    ];
  };
}
