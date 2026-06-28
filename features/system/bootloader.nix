{ lib, mkFeature, ... }:

mkFeature {
  name = "bootloader";
  enableByDefault = true;

  nixos = { ... }: {
    boot.loader = {
      grub = {
        enable = true;
        efiSupport = true;
        useOSProber = true;
        device = "nodev";
      };
      efi.canTouchEfiVariables = true;
    };
  };
}
