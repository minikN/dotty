{ lib }:

pkgs:
{ name
, config
, elispPackages ? _: [ ]
, summary ? "No description provided"
, earlyInit ? ""
, addToInitEl ? true
, manual ? null
}:
{
  programs.emacs = {
    extraPackages = epkgs:
      let
        deps = elispPackages epkgs;
        elFile = pkgs.writeText "${name}.el" ''
          ;;; ${name}.el --- ${summary} -*- lexical-binding: t -*-

          ${config}
          (provide '${name})
        '';
        ## building manual
        src = if manual == null then elFile else pkgs.runCommand "${name}-src" { } ''
          mkdir $out
          cp ${elFile} $out/${name}.el
          cp ${manual} ${name}.org
          ${epkgs.emacs}/bin/emacs --batch -Q ${name}.org \
            --eval "(progn (require 'ox-texinfo) (org-texinfo-export-to-texinfo))"
          cp ${name}.texi $out/
        '';
      in
      deps ++ [
        (epkgs.melpaBuild {
          pname = name;
          version = "0.1.0";
          inherit src;
          packageRequires = deps;
          ignoreCompilationError = true;
        })
      ];
    extraConfig = lib.optionalString addToInitEl "(require '${name})";
  };

  features.emacs.earlyInit = earlyInit;
}
