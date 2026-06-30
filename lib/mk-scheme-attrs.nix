{ lib }:

## Attach a `withHashtag` variant ({ base00 = "#ffffff"; ... }) to a base16 scheme.
scheme:
scheme // {
  withHashtag = lib.mapAttrs (_: v: "#${v}") scheme;
}
