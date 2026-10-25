# Personal Nix configuration

My NixOS, nix-darwin, and home-manager configuration, built on
[tessera](../tessera). Tessera provides the framework (`mkFeature`,
`mkFlake`, …) and most features; this repository holds my hosts, secrets,
and the features that only make sense for me. See tessera's README for how
hosts and features work.

```
flake.nix      # tessera.lib.mkFlake { inputs; globals; hosts; features; }
globals.nix    # user name, email, GPG key, state version
hosts/         # one file per machine
features/      # my own features (discovered like tessera's)
keys/          # public SSH keys
secrets/       # agenix-encrypted secrets
```

## Updating tessera

Tessera is a `git+file` flake input, pinned in `flake.lock`. After
committing a change in tessera, pull it in and rebuild:

```bash
nix flake update tessera
```

To try uncommitted tessera changes without touching the lock file:

```bash
sudo -E darwin-rebuild switch --flake .#workhorse \
  --override-input tessera ~/.local/share/git/tessera
```

## Deploying

### Local nix-darwin host

```bash
sudo -E darwin-rebuild switch --flake .#workhorse
```

`-E` preserves the invoking user's environment so user-level bits (e.g.
`$HOME`, `$USER`) stay correct after `sudo`. `switch` builds the new
generation and activates it.

### Remote NixOS host (over SSH)

```bash
nix run nixpkgs#nixos-rebuild -- switch --flake .#orcshed \
  --target-host db@10.0.0.10 --build-host db@10.0.0.10 \
  --elevate=sudo --ask-elevate-password
```

- `nix run nixpkgs#nixos-rebuild --` — pulls `nixos-rebuild` from nixpkgs
  on demand, useful when running from a darwin host that doesn't have it
  installed.
- `--flake .#orcshed` — the host config from this flake.
- `--target-host db@10.0.0.10` — SSH endpoint that performs the activation.
- `--build-host db@10.0.0.10` — also build there. Pointing it at the
  target avoids cross-compiling `x86_64-linux` on `aarch64-darwin`. Drop
  it if you already have a Linux remote builder configured.
- `--elevate=sudo --ask-elevate-password` — escalate to root via `sudo`
  on the remote, prompting for the sudo password locally (rather than
  requiring NOPASSWD).

### Standalone home-manager (no system config)

```bash
home-manager switch --flake .#slimboy
```

## My features

| Feature                     | Purpose                                               |
| --------------------------- | ----------------------------------------------------- |
| `services/*`                | Home server services (Jellyfin, nixarr, Caddy, …)     |
| `system/nas.nix`            | SMB mounts of my NAS                                  |
| `system/filesystem.nix`     | My disk layout (labels `SYSTEM`, `BOOT`, `SWAP`)      |
| `system/zmk/`               | Firmware and flash script for my Corne keyboard       |

## Secrets

Secrets use [agenix](https://github.com/ryantm/agenix). Encrypted `*.age` files
live in `secrets/`; recipients are declared in `secrets/secrets.nix`. Each host
imports the agenix module and declares its secrets under `age.secrets.<name>`,
which decrypt to `/run/agenix/<name>` at boot.

A new secret touches three places:

1. **`secrets/secrets.nix`** — declare who can decrypt it:

   ```nix
   "wg-1.conf.age".publicKeys = [ db orcshed ];
   ```

2. **The host's `nixos` block** (e.g. `hosts/orcshed.nix`) — declare the secret
   so agenix decrypts it on that host:

   ```nix
   age.secrets."wg-1.conf" = {
     file = ../secrets/wg-1.conf.age;
     owner = "root";
     group = "root";
     mode = "0600";
   };
   ```

3. **Where it's used** — pass the runtime path (never the `.age` file) to the
   consumer. Options needing `config` go in the `features` function block:

   ```nix
   features = { config, ... }: {
     nixarr.wgConf = config.age.secrets."wg-1.conf".path;
   };
   ```

Then encrypt the file itself with the commands below.

Run the commands from `secrets/` (agenix reads `./secrets.nix`) via the flake
app — no local install needed. `-i` points at your age private key.

Edit or create a secret (a new one needs its entry in `secrets.nix` first):

```bash
cd secrets
nix run github:ryantm/agenix -- -e wg-1.conf.age -i ~/.config/age/keys.txt
```

Re-key all secrets after changing recipients in `secrets.nix`:

```bash
cd secrets
nix run github:ryantm/agenix -- -r -i ~/.config/age/keys.txt
```

## Testing

```bash
# Evaluate every output (fast, catches type/eval errors)
nix flake check --no-build

# Build without activating
nix build .#darwinConfigurations.workhorse.system
nix build .#nixosConfigurations.slimboy.config.system.build.toplevel
nix build .#homeConfigurations.workhorse.activationPackage
```

## License

GPLv3 — see [LICENSE](./LICENSE).
