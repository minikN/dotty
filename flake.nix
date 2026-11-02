{
  description = "Personal Nix configuration.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    tessera = {
      url = "git+file:../tessera";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixarr = {
      url = "github:nix-media-server/nixarr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zmk-nix = {
      url = "github:lilyinstarlight/zmk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.tessera.lib.mkFlake {
    inherit inputs;
    globals = {
      user = "db";
      fullName = "Demis Balbach";
      email = "db@minikn.xyz";
      gpgKey = "F17DDB98CC3C405C";
      stateVersion = "26.05";
    };
    hosts = ./hosts;
    features = ./features;
  };
}
