## Recipients catalogue — each `*.age` file lists the public keys that
## can decrypt it. The agenix CLI reads this file when encrypting and
## editing.
##
## Add a new recipient (user key or host SSH key), then re-key existing
## secrets with `agenix -r` so they accept the new recipient.
let
  ## Personal age identity. Private key lives at
  ## ~/.config/age/keys.txt (NEVER commit), generated via `age-keygen`.
  db = "age17kq5saynaug8ekun6k2xenz5vsgks8juczcqszlqpvlk9kw0hymqwwlv63";

  ## Host SSH host keys — agenix uses these so each NixOS box can
  ## decrypt secrets at activation time using its own
  ## /etc/ssh/ssh_host_ed25519_key. Grab them with:
  ##   ssh <host> 'cat /etc/ssh/ssh_host_ed25519_key.pub'
  orcshed = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINjLXu5aJP+653XFeGVZLXluJtT+B+RYUpULJq9Jt6gx";
in
{
  "smb-credentials.age".publicKeys = [ db orcshed ];
}
