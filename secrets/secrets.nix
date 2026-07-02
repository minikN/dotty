## agenix recipients catalogue. Re-key with `agenix -r` after editing.
let
  ## Private key at ~/.config/age/keys.txt (never commit).
  db = "age17kq5saynaug8ekun6k2xenz5vsgks8juczcqszlqpvlk9kw0hymqwwlv63";

  ## ssh <host> 'cat /etc/ssh/ssh_host_ed25519_key.pub' to add a host.
  orcshed = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINjLXu5aJP+653XFeGVZLXluJtT+B+RYUpULJq9Jt6gx";
in
{
  "smb-credentials.age".publicKeys = [ db orcshed ];
  "wg-1.age".publicKeys = [ db orcshed ];
  "wg-2.age".publicKeys = [ db orcshed ];
  "wg-3.age".publicKeys = [ db orcshed ];
}
