{ lib }:

rec {
  nixFilesIn = dir:
    builtins.filter
      (f: lib.hasSuffix ".nix" (toString f))
      (lib.filesystem.listFilesRecursive dir);

  discoverFeatures = featuresDir: helpers:
    map (f: (import f) ({ inherit lib; } // helpers)) (nixFilesIn featuresDir);

  discoverHosts = hostsDir:
    map
      (f: {
        name = lib.removeSuffix ".nix" (baseNameOf (toString f));
        file = f;
      })
      (nixFilesIn hostsDir);
}
