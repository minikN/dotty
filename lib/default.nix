{ lib }:

let
  mkFeature = import ./mk-feature.nix { inherit lib; };
  mkHost = import ./mk-host.nix { inherit lib; };
  mkSchemeAttrs = import ./mk-scheme-attrs.nix { inherit lib; };
  discover = import ./discover.nix { inherit lib; };
in
{
  inherit mkFeature mkHost mkSchemeAttrs;
  inherit (discover) discoverFeatures discoverHosts;
}
