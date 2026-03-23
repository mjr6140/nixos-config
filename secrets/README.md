# Secrets

This repo uses `agenix` for encrypted runtime secrets.

Files:

- `secrets/secrets.nix`: maps encrypted files to their allowed public-key recipients
- `secrets/*.age`: encrypted secret payloads committed to the repo

Current secret files:

- `snapraid-healthchecks.env.age`: Healthchecks.io base ping URLs for the fileserver SnapRAID jobs

Editing:

```sh
cd /home/matt/nixos-config/secrets
RULES=./secrets.nix agenix -i <(ssh-to-age -private-key -i ~/.ssh/id_ed25519) -e snapraid-healthchecks.env.age
```

Expected plaintext format:

```sh
HC_SNAPRAID_SYNC_URL=
HC_SNAPRAID_SCRUB_URL=
```

The fileserver decrypts this secret at activation/runtime to:

```sh
/run/agenix/snapraid-healthchecks-env
```

The encrypted secret file must be tracked in Git (`git add secrets/snapraid-healthchecks.env.age`) so flake builds include it.

The fileserver VM uses a dedicated age identity at:

```sh
/var/lib/agenix/identity
```

That key is provisioned by `scripts/create-fileserver-vm.sh` from the host-side file:

```sh
/home/matt/.local/share/nixos-fileserver-vm/agenix/identity
```
