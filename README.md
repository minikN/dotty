# Personal Nix configuration

## Updating tessera

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

### Remote NixOS host (over SSH)

```bash
nix run nixpkgs#nixos-rebuild -- switch --flake .#orcshed \
  --target-host db@10.0.0.10 --build-host db@10.0.0.10 \
  --elevate=sudo --ask-elevate-password
```

## Encryption

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
nix flake check --no-build
nix build .#darwinConfigurations.workhorse.system
nix build .#nixosConfigurations.slimboy.config.system.build.toplevel
nix build .#homeConfigurations.workhorse.activationPackage
```

## License

GPLv3 — see [LICENSE](./LICENSE).
