{ lib }:

pkgs:
{ name
, config
, elispPackages ? _: [ ]  ## epkgs: [ ... ], resolved against the configured Emacs
, summary ? "No description provided"
, earlyInit ? ""
, addToInitEl ? true
}:
{
  programs.emacs = {
    extraPackages = epkgs:
      let
        deps = elispPackages epkgs;
      in
      deps ++ [
        (epkgs.melpaBuild {
          pname = name;
          version = "0.1.0";
          src = pkgs.writeText "${name}.el" ''
            ;;; ${name}.el --- ${summary} -*- lexical-binding: t -*-

            ${config}
            (provide '${name})
          '';
          packageRequires = deps;
          ignoreCompilationError = true;
        })
      ];
    extraConfig = lib.optionalString addToInitEl "(require '${name})";
  };

  features.emacs.earlyInit = earlyInit;
}
