{ lib, mkFeature, ... }:

## Custom ZMK firmware for the wireless Corne (nice!nano v2 + nice!view),
## built with zmk-nix. Customise keys in ./config/corne.{keymap,conf} or live
## over USB with ZMK Studio. Installs the Studio app plus a `corne-flash`
## helper that writes the freshly built firmware onto each half.
mkFeature {
  name = "zmk";

  darwin = { inputs, pkgs, ... }:
    let
      zmk = inputs.zmk-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};

      firmware = zmk.buildSplitKeyboard {
        name = "corne-firmware";

        src = lib.sourceFilesBySuffices ./. [
          ".board" ".cmake" ".conf" ".defconfig" ".dts" ".dtsi"
          ".json" ".keymap" ".overlay" ".shield" ".yml" "_defconfig"
        ];

        board = "nice_nano@2.0.0//zmk";
        shield = "corne_%PART% nice_view_adapter nice_view";
        enableZmkStudio = true;

        ## The West deps are pinned by config/west.yml, so this hash tracks that
        ## manifest (identical to the one zmk-nix ships). Bump config/west.yml and
        ## `nix build` will print the corrected value on mismatch.
        zephyrDepsHash = "sha256-GvtT42CxvQfcEoVjlsT0gMNN0PWR/TiHmNab/My12Kg=";

        meta = {
          description = "ZMK firmware for the wireless Corne";
          license = lib.licenses.mit;
          platforms = lib.platforms.all;
        };
      };

      ## macOS flasher. The nice!nano bootloader mounts as a USB volume named
      ## NICENANO; drop the matching half's .uf2 onto it. (zmk-nix's own flasher
      ## is Linux-only — it relies on lsblk/udisks.)
      flash = pkgs.writeShellApplication {
        name = "corne-flash";
        text = ''
          for part in ${toString firmware.parts}; do
            echo "Double-tap reset on the $part half and connect it via USB."

            vol=""
            while [ -z "$vol" ]; do
              for v in /Volumes/*NICENANO*; do
                if [ -d "$v" ]; then vol="$v"; break; fi
              done
              if [ -z "$vol" ]; then sleep 1; fi
            done

            echo "Flashing $part onto $vol ..."
            # The board reboots mid-copy, so a write error here is expected.
            cp ${firmware}/zmk_"$part".uf2 "$vol"/ || true

            echo "Done — waiting for the $part half to reboot ..."
            while [ -d "$vol" ]; do sleep 1; done
          done
          echo "All halves flashed."
        '';
      };
    in
    {
      environment.systemPackages = [
        pkgs.zmk-studio
        flash
      ];
    };
}
