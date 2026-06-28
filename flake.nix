{
  description = "Personal Nix configuration.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    let
      lib = inputs.nixpkgs.lib;
      flakeLib = import ./lib { inherit lib; };

      globals = import ./globals.nix;
      features = flakeLib.discoverFeatures ./features flakeLib.mkFeature;
      hostEntries = flakeLib.discoverHosts ./hosts;

      builtHosts = builtins.listToAttrs (map
        (h: {
          inherit (h) name;
          value = flakeLib.mkHost {
            inherit inputs globals features;
            inherit (h) name file;
          };
        })
        hostEntries);

      onPlatform = platform:
        lib.mapAttrs (_: v: v.systemConfig)
          (lib.filterAttrs (_: v: v.platform == platform) builtHosts);
    in
    {
      nixosConfigurations = onPlatform "nixos";
      darwinConfigurations = onPlatform "darwin";
      homeConfigurations = lib.mapAttrs (_: v: v.homeConfig) builtHosts;
    };
}
