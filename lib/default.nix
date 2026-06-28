{ lib }:

let
  mkFeature = import ./mk-feature.nix { inherit lib; };
  mkHost = import ./mk-host.nix { inherit lib; };
  discover = import ./discover.nix { inherit lib; };
in
{
  inherit mkFeature mkHost;
  inherit (discover) discoverFeatures discoverHosts;
}
