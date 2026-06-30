{ lib }:

## Enrich a base16 scheme attrset with derived variants.
##
##   { base00 = "ffffff"; ...; base0F = "624416"; }
##   → { base00 = "ffffff"; ...; withHashtag = { base00 = "#ffffff"; ... }; }
##
## Mirrors the subset of SenchoPens/base16.nix's mkSchemeAttrs that dotty
## actually uses — no mustache templating, no slug, just the withHashtag
## variant that downstream features (ghostty, sway, …) need.
scheme:
scheme // {
  withHashtag = lib.mapAttrs (_: v: "#${v}") scheme;
}
