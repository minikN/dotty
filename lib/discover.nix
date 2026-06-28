{ lib }:

rec {
  nixFilesIn = dir:
    builtins.filter
      (f: lib.hasSuffix ".nix" (toString f))
      (lib.filesystem.listFilesRecursive dir);

  discoverFeatures = featuresDir: mkFeature:
    map (f: (import f) { inherit lib mkFeature; }) (nixFilesIn featuresDir);

  discoverHosts = hostsDir:
    map
      (f: {
        name = lib.removeSuffix ".nix" (baseNameOf (toString f));
        file = f;
      })
      (nixFilesIn hostsDir);
}
