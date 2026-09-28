{ lib, mkFeature, ... }:

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

        ## hash for config/west.yml
        zephyrDepsHash = "sha256-GvtT42CxvQfcEoVjlsT0gMNN0PWR/TiHmNab/My12Kg=";

        meta = {
          description = "ZMK firmware for the wireless Corne";
          license = lib.licenses.mit;
          platforms = lib.platforms.all;
        };
      };

      corne-flash = pkgs.writeShellApplication {
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
            cp -X ${firmware}/zmk_"$part".uf2 "$vol"/ || true

            echo "Done — waiting for the $part half to reboot ..."
            while [ -d "$vol" ]; do sleep 1; done
          done
          echo "All halves flashed."
        '';
      };
    in
    {
      environment.systemPackages = [
        corne-flash
      ];
    };
}
