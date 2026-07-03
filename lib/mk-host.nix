{ lib }:

{ inputs
, globals
, features
, name
, file
}:

let
  inherit (lib) mkDefault;

  hostDef = import file;

  system = hostDef.system;
  platform = if lib.strings.hasInfix "darwin" system then "darwin" else "nixos";

  hostFeatures = hostDef.features or { };
  hostNixos = hostDef.nixos or { };
  hostDarwin = hostDef.darwin or { };
  hostHome = hostDef.home or { };

  user = globals.user;

  globalsOptionsModule = import ./globals-options.nix;

  staticGlobalsModule = { ... }: {
    config.globals.user = globals;
    config.globals.platform = platform;
  };

  hostFeaturesModule = args: {
    config.features =
      if builtins.isFunction hostFeatures then hostFeatures args else hostFeatures;
  };

  filterNonNull = builtins.filter (m: m != null);

  commonFeatureModules = map (f: f.commonModule) features;
  homeFeatureModules = filterNonNull (map (f: f.homeModule) features);
  nixosFeatureModules = filterNonNull (map (f: f.nixosModule) features);
  darwinFeatureModules = filterNonNull (map (f: f.darwinModule) features);

  homeModules = [
    globalsOptionsModule
    staticGlobalsModule
    hostFeaturesModule
    { home.stateVersion = mkDefault globals.stateVersion; }
  ]
  ++ commonFeatureModules
  ++ homeFeatureModules
  ++ [ hostHome ];

  systemHomeManagerModule = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "backup";
    home-manager.users.${user}.imports = homeModules;
  };

  systemModules = [
    globalsOptionsModule
    staticGlobalsModule
    hostFeaturesModule
    { nixpkgs.config.allowUnfree = true; }
    systemHomeManagerModule
  ]
  ++ commonFeatureModules
  ++ (if platform == "nixos" then nixosFeatureModules else darwinFeatureModules)
  ++ [ (if platform == "nixos" then hostNixos else hostDarwin) ];

  systemConfig =
    if platform == "nixos" then
      inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs globals; };
        modules = [
          inputs.home-manager.nixosModules.home-manager
          { system.stateVersion = mkDefault globals.stateVersion; }
        ] ++ systemModules;
      }
    else
      inputs.darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit inputs globals; };
        modules = [
          inputs.home-manager.darwinModules.home-manager
          { system.stateVersion = mkDefault 6; }
        ] ++ systemModules;
      };

  homeConfig = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    extraSpecialArgs = { inherit inputs globals; };
    modules = homeModules;
  };
in
{
  inherit name platform system systemConfig homeConfig;
}
