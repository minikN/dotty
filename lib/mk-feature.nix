{ lib }:

{ name
, options ? { }
, home ? null
, nixos ? null
, darwin ? null
, globals ? null
, enableByDefault ? false
, ...
}:

let
  inherit (lib) mkIf mkOption setAttrByPath getAttrFromPath concatStringsSep types;

  fname = if builtins.isList name then name else [ name ];
  optionPath = [ "features" ] ++ fname;
  enablePath = optionPath ++ [ "enable" ];
  niceName = concatStringsSep "." fname;

  callBlock = block: args:
    if builtins.isFunction block then block args else block;

  mkBody = block: args@{ config, pkgs, lib, ... }:
    let
      mod = callBlock block args;
      rest = builtins.removeAttrs mod [ "imports" "options" ];
    in
    {
      imports = mod.imports or [ ];
      config = mkIf (getAttrFromPath enablePath config) rest;
    };

  commonModule = args@{ config, pkgs, lib, ... }:
    let
      userOptions = callBlock options args;
      userGlobals = if globals == null then { } else callBlock globals args;
    in
    {
      options = setAttrByPath optionPath ({
        enable = mkOption {
          type = types.bool;
          default = enableByDefault;
          example = !enableByDefault;
          description = "Whether to enable the ${niceName} feature.";
        };
      } // userOptions);
      config.globals = userGlobals;
    };
in
{
  inherit name commonModule;
  nixosModule = if nixos == null then null else mkBody nixos;
  darwinModule = if darwin == null then null else mkBody darwin;
  homeModule = if home == null then null else mkBody home;
}
