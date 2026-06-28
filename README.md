# Personal Nix configuration

Single-flake setup covering NixOS, nix-darwin, and home-manager. Hosts are
discovered from `hosts/`, features from `features/`. There is no central
"register every machine here" file: drop a `.nix` file in the right folder
and it is picked up.

## Layout

```
.
├── flake.nix                 # entry point — discovers hosts/features and dispatches
├── globals.nix               # static constants (user, email, gpgKey, stateVersion)
├── lib/
│   ├── default.nix
│   ├── discover.nix          # walks hosts/ and features/
│   ├── globals-options.nix   # declares options.globals.*
│   ├── mk-feature.nix        # feature helper
│   └── mk-host.nix           # builds a host's system + home configurations
├── hosts/                    # one file per host (filename = host name)
│   ├── slimboy.nix
│   └── workhorse.nix
└── features/                 # feature modules; folder layout is free
    ├── core/
    │   ├── home.nix
    │   └── user-info.nix
    ├── shell/
    │   └── zsh.nix
    └── system/
        ├── base.nix
        ├── bootloader.nix
        ├── filesystem.nix
        └── nas.nix
```

## How it works

`flake.nix` does three things:

1. Loads `globals.nix` (your static constants).
2. Recursively imports every `.nix` file under `features/` via `mkFeature`,
   producing a list of feature records.
3. Walks `hosts/` and builds, for each host file:
   - `nixosConfigurations.<host>` *or* `darwinConfigurations.<host>` —
     dispatched on `system` (anything containing `darwin` → nix-darwin, else
     NixOS).
   - `homeConfigurations.<host>` — a standalone `homeManagerConfiguration`
     built from the *same* home modules that the system config embeds.

So every host gets both an embedded path (`{nixos,darwin}-rebuild switch`,
system + home together) and a standalone path (`home-manager switch`, home
only) for free.

```bash
sudo darwin-rebuild switch --flake .#workhorse
sudo nixos-rebuild  switch --flake .#slimboy
home-manager        switch --flake .#slimboy
```

## Hosts

A host file is a plain attrset. The filename (without `.nix`) is the host
name. The only required key is `system`; the platform is inferred from it.

```nix
# hosts/slimboy.nix
{
  system = "x86_64-linux";

  features = {
    zsh = {
      enable = true;
      extraConfig = ''
        export PATH="$HOME/.local/bin:$PATH"
      '';
    };
  };

  nixos = { pkgs, ... }: {
    networking.hostName = "slimboy";
    boot.kernelModules = [ "kvm-intel" ];
    boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux_latest;
  };

  home = { ... };   # optional — host-specific home-manager config
}
```

| Key        | Required | Purpose                                                   |
| ---------- | -------- | --------------------------------------------------------- |
| `system`   | yes      | `x86_64-linux`, `aarch64-darwin`, etc.                    |
| `features` | no       | Toggle features and set their options.                    |
| `nixos`    | no       | Host-specific NixOS config. Ignored on darwin hosts.      |
| `darwin`   | no       | Host-specific nix-darwin config. Ignored on NixOS hosts.  |
| `home`     | no       | Host-specific home-manager config.                        |

## Features

A feature is built with the `mkFeature` helper. It can declare three
platform blocks (`nixos`, `darwin`, `home`) plus shared options and a
contribution to the global namespace. Every block is independently optional.

### Minimal feature

```nix
# features/shell/zsh.nix
{ lib, mkFeature, ... }:

mkFeature {
  name = "zsh";

  options = { pkgs, ... }: {
    package = lib.mkPackageOption pkgs "zsh" { };
  };

  home = { config, ... }: {
    programs.zsh.enable = true;
    programs.zsh.package = config.features.zsh.package;
  };
}
```

Enable on any host with `features.zsh.enable = true;`.

### Full anatomy

```nix
mkFeature {
  name = "myFeature";        # string or list of strings (nested: ["foo" "bar"])
  enableByDefault = false;   # if true, the feature is on unless a host disables it

  options = { config, pkgs, ... }: {
    # Options live under features.<name>.*
    # An `enable` option is always synthesized — don't redeclare it.
  };

  globals = { config, ... }: {
    # Optional. Contributions to config.globals.*
    # e.g. apps.shell = lib.mkIf config.features.zsh.enable "...";
  };

  nixos  = { config, pkgs, ... }: { ... };  # only goes into NixOS hosts
  darwin = { config, pkgs, ... }: { ... };  # only goes into darwin hosts
  home   = { config, pkgs, ... }: { ... };  # goes into the user's home-manager config
}
```

Each block's body is automatically wrapped in
`mkIf config.features.<name>.enable`, so you don't gate it yourself. The
`home` block runs in *both* the embedded home-manager (inside the system
config) and the standalone `homeConfigurations.<host>` output — keep it
free of system-level options.

### Cross-platform feature

```nix
# features/system/base.nix
{ lib, mkFeature, ... }:

mkFeature {
  name = "base";
  enableByDefault = true;

  options = {
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Berlin";
    };
  };

  nixos  = { config, ... }: { time.timeZone = config.features.base.timeZone; };
  darwin = { config, ... }: { time.timeZone = config.features.base.timeZone; };
}
```

## Globals

Two layers, both reachable as `config.globals.*`:

1. **User constants** — whatever is in `globals.nix`, copied verbatim into
   `config.globals.user`. So `config.globals.user.user`,
   `config.globals.user.email`, `config.globals.user.gpgKey`, etc.

2. **Framework/feature globals** — declared as options in
   `lib/globals-options.nix`:
   - `config.globals.platform` — `"nixos"` or `"darwin"`, auto-set per host.
   - `config.globals.apps.{shell,terminal,editor,wm,launcher}` — populated
     by features that contribute defaults.

Features read globals like any other config value:

```nix
nixos = { config, ... }: {
  environment.shells = lib.optional (config.globals.apps.shell != null)
    config.globals.apps.shell;
};
```

And contribute to them via the `globals` block of `mkFeature`:

```nix
globals = { config, ... }: {
  apps.shell = lib.mkIf config.features.zsh.enable
    "${config.features.zsh.package}/bin/zsh";
};
```

## Adding things

- **A new host** — drop a file in `hosts/`. Filename = host name.
- **A new feature** — drop a file in `features/<wherever>/<name>.nix`. Folder
  structure is purely organizational; discovery is recursive.
- **Platform-specific behavior on an existing feature** — add or extend its
  `nixos = …`, `darwin = …`, or `home = …` block.

## Testing

```bash
# Evaluate every output (fast, catches type/eval errors)
nix flake check --no-build

# Inspect outputs. darwinConfigurations / homeConfigurations show as
# "unknown" because nix has no schema for them — this is fine.
nix flake show
nix eval .#darwinConfigurations --apply builtins.attrNames
nix eval .#homeConfigurations   --apply builtins.attrNames

# Build without activating
nix build .#darwinConfigurations.workhorse.system
nix build .#nixosConfigurations.slimboy.config.system.build.toplevel
nix build .#homeConfigurations.workhorse.activationPackage
```

## License

GPLv3 — see [LICENSE](./LICENSE).

## Acknowledgements

The feature/host pattern used here originated from
[migalmoreno/ordenada](https://github.com/migalmoreno/ordenada) (private). The
`mkFeature` helper, the platform-block layout (`nixos` / `darwin` / `home`),
and the globals/feature module wiring are all adapted from that project.
