# Secrets

This repo uses `agenix` for encrypted runtime secrets.

Files:

- `secrets/secrets.nix`: maps encrypted files to their allowed public-key recipients
- `secrets/*.age`: encrypted secret payloads committed to the repo

Current secret files:

- `snapraid-healthchecks.env.age`: Healthchecks.io base ping URLs for the fileserver SnapRAID jobs
- `pihole.env.age`: Pi-hole runtime env fragment
- `caddy.env.age`: Caddy runtime env fragment
- `karakeep.env.age`: Karakeep runtime env fragment
- `gluetun.env.age`: Gluetun runtime env fragment
- `restic-nixos-desktop.env.age`: Desktop restic repo config and password env
- `restic-nixos-desktop-ssh.age`: Desktop restic SSH private key
- `restic-nixos-minipc.env.age`: Mini PC local restic repo password and Healthchecks env
- `restic-nixos-minipc-vps.env.age`: Mini PC VPS restic repo password and Healthchecks env
- `restic-nixos-minipc-vps-ssh.age`: Mini PC VPS restic SSH private key

Pattern:

- use one encrypted env fragment per stack
- secret file names follow `<stack>.env.age`
- decrypted files are exposed at `/run/agenix/<stack>.env`
- the generic Compose module appends those contents into `/srv/compose/<stack>/.env`
- exceptions are allowed when the secret is not an env fragment, for example an SSH private key used by a backup job

Editing:

```sh
cd /home/matt/nixos-config/secrets
RULES=./secrets.nix agenix -e pihole.env.age
```

Expected plaintext format:

```sh
KEY=value
ANOTHER_KEY=value
```

Examples:

```sh
# pihole.env.age
FTLCONF_webserver_api_password=

# caddy.env.age
PORKBUN_API_KEY=
PORKBUN_API_SECRET_KEY=

# karakeep.env.age
NEXTAUTH_SECRET=
NEXTAUTH_URL=
MEILI_MASTER_KEY=
OPENAI_API_KEY=

# gluetun.env.age
WIREGUARD_PRIVATE_KEY=
WIREGUARD_PRESHARED_KEY=
WIREGUARD_ADDRESSES=

# restic-nixos-minipc.env.age
RESTIC_PASSWORD=
HC_RESTIC_BACKUPS_URL=

# restic-nixos-minipc-vps.env.age
RESTIC_PASSWORD=
HC_RESTIC_BACKUPS_URL=

# restic-nixos-desktop.env.age
RESTIC_REPOSITORY=sftp:restic@10.12.1.99:/mnt/tank/backup-repos/restic/nixos-desktop
RESTIC_PASSWORD=
HC_RESTIC_BACKUPS_URL=

# restic-nixos-desktop-ssh.age
# OpenSSH private key contents

# snapraid-healthchecks.env.age
HC_SNAPRAID_SYNC_URL=
HC_SNAPRAID_SCRUB_URL=
```

Example runtime path on a host:

```sh
/run/agenix/pihole.env
```

The encrypted secret file must be tracked in Git (`git add secrets/snapraid-healthchecks.env.age`) so flake builds include it.

Any host that needs to decrypt agenix-managed runtime secrets should use a dedicated host age identity at:

```sh
/var/lib/agenix/identity
```

Rekey all secrets after changing recipients in `secrets/secrets.nix`:

```sh
cd /home/matt/nixos-config/secrets
RULES=./secrets.nix agenix -r
```
