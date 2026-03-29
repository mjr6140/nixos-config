# Mini PC Disaster Recovery

This is the recovery runbook for rebuilding `nixos-minipc` after total hardware loss.

The intended model is:

- Nix rebuilds the machine configuration
- restic restores local state
- NFS remounts shared content
- agenix/SSH keys restore host identity and secret decryption

## What Must Exist Before Recovery

You need access to all of the following:

- this git repo, including `secrets/*.age`
- a private key that can decrypt the agenix secrets
- the restic repository password for `nixos-minipc`
- the restic repository itself:
  - `/mnt/tank/backup-repos/restic/nixos-minipc`
- the NAS exports used by the host:
  - content
  - media
  - backup repos

For secret recovery, at least one of these must be available:

- the `matt` SSH private key that matches the recipient in `secrets/secrets.nix`
- the old host age identity:
  - `/var/lib/agenix/identity`

## Recovery Goals

After recovery, the host should match the pre-failure state closely enough that:

- the host name and system config are the same
- agenix secrets decrypt normally
- SSH host keys are preserved
- Compose stack data under `/srv/appdata` is restored
- services start against the same NFS-backed content

## High-Level Order

1. Install fresh NixOS on replacement hardware.
2. Clone the repo locally on the replacement host.
3. Replace the checked-in hardware config with the newly generated one.
4. Restore the old agenix identity and SSH host keys if available.
5. Rebuild `nixos-minipc`.
6. Confirm NFS mounts work.
7. Restore `/srv/appdata` from restic.
8. Restart and validate services.

## Step 1: Install Fresh NixOS

Install NixOS on the replacement machine with the same rough storage layout:

- EFI partition
- ext4 root
- swap partition

After first boot, log in as `matt`.

## Step 2: Clone The Repo

On the replacement host:

```bash
git clone <your-repo-url> /home/matt/nixos-config
cd /home/matt/nixos-config
```

If the repo is already available by other means, place it at:

- `/home/matt/nixos-config`

## Step 3: Replace The Hardware Config

Copy the newly generated hardware config into the tracked host path:

```bash
sudo cp /etc/nixos/hardware-configuration.nix \
  /home/matt/nixos-config/hosts/nixos-minipc/hardware-configuration.nix
```

This is important. Do not assume the previously committed hardware config is correct for replacement hardware.

## Step 4: Restore Key Material First

The best recovery path is to restore these before the first rebuild:

- `/var/lib/agenix/identity`
- `/etc/ssh`

Why:

- `agenix` can decrypt secrets immediately after rebuild
- the host keeps the same SSH host identity

### Option A: You Have The Old Copies Available Separately

Restore them directly now:

```bash
sudo mkdir -p /var/lib/agenix
sudo rsync -aHAX /path/to/recovered/identity /var/lib/agenix/identity
sudo chmod 600 /var/lib/agenix/identity

sudo rsync -aHAX /path/to/recovered/etc-ssh/ /etc/ssh/
```

### Option B: You Only Have The Restic Backup

You can still proceed, but the cleanest full restoration of host identity will happen after the first restore.

In that case:

- make sure you still have a decrypting key for agenix, such as the `matt` SSH private key
- proceed with the rebuild
- restore `/var/lib/agenix/identity` and `/etc/ssh` from restic afterward

## Step 5: Apply The NixOS Config

Run the first rebuild locally on the replacement host:

```bash
cd /home/matt/nixos-config
sudo nixos-rebuild switch --flake .#nixos-minipc
```

The first apply is intentionally local. Do not rely on remote `--target-host` bootstrap for a fresh machine.

## Step 6: Verify Core Mounts

After the rebuild, make sure the expected NFS mounts work:

```bash
ls /srv/content/data
ls /srv/content/media
ls /mnt/backup-repos
```

If those do not work, fix networking/NFS before continuing.

## Step 7: Verify Secret Access

If agenix is correctly restored and wired, these should exist:

```bash
sudo ls -l /run/agenix
sudo cat /run/agenix/caddy.env
sudo cat /run/agenix/karakeep.env
sudo cat /run/agenix/pihole.env
sudo cat /run/agenix/restic-nixos-minipc.env
```

Do not paste secret contents anywhere public. This check is only to confirm decryption works.

## Step 8: Restore The Restic Snapshot

Create a temporary restore location:

```bash
sudo mkdir -p /tmp/restic-restore
```

Inspect available snapshots:

```bash
sudo restic-nixos-minipc snapshots
```

Restore the latest one:

```bash
sudo restic-nixos-minipc restore latest --target /tmp/restic-restore
```

## Step 9: Restore Files Into Place

Restore the three important areas:

```bash
sudo rsync -aHAX /tmp/restic-restore/srv/appdata/ /srv/appdata/
sudo rsync -aHAX /tmp/restic-restore/var/lib/agenix/identity /var/lib/agenix/identity
sudo rsync -aHAX /tmp/restic-restore/etc/ssh/ /etc/ssh/
```

Then fix the agenix identity permissions:

```bash
sudo chmod 600 /var/lib/agenix/identity
```

## Step 10: Rebuild Again

After restoring `/var/lib/agenix/identity` and `/etc/ssh`, rebuild once more so the host is running against the restored identity material:

```bash
cd /home/matt/nixos-config
sudo nixos-rebuild switch --flake .#nixos-minipc
```

## Step 11: Start And Verify Services

Bring the stacks up or restart them:

```bash
sudo systemctl restart caddy-compose
sudo systemctl restart pihole-compose
sudo systemctl restart gluetun-compose
sudo systemctl restart karakeep-compose
sudo systemctl restart jellyfin-compose
sudo systemctl restart sabnzbd-compose
sudo systemctl restart arr-compose
```

Check status:

```bash
systemctl --no-pager --full status \
  caddy-compose \
  pihole-compose \
  gluetun-compose \
  karakeep-compose \
  jellyfin-compose \
  sabnzbd-compose \
  arr-compose
```

## Step 12: Validate The Host

Validate the important endpoints:

- `https://pihole.undead.one`
- `https://jellyfin.undead.one`
- `https://sabnzbd.undead.one`
- `https://karakeep.undead.one`
- `https://radarr.undead.one`
- `https://sonarr.undead.one`
- `https://prowlarr.undead.one`

Validate direct local services if needed:

```bash
curl -I http://127.0.0.1:3000
curl -I http://127.0.0.1:8080
curl -I http://127.0.0.1:9090
```

## Notes On What Does Not Need Backup Restore

These are rebuildable and should not be restored from backup:

- `/nix/store`
- generated Compose files under `/srv/compose`
- Docker images
- NFS-mounted content under `/srv/content`

The important local state is:

- `/srv/appdata`
- `/var/lib/agenix/identity`
- `/etc/ssh`

## If The Old Host Identity Is Missing

Recovery is still possible if:

- you can decrypt agenix secrets using the `matt` recipient key
- you can access the restic repo password

In that case:

- rebuild the host
- restore appdata
- generate a new host age identity
- update `secrets/secrets.nix`
- rekey secrets with `agenix -r`

This is more work, but it is not catastrophic as long as your user key can still decrypt the secrets.

## Recommended Post-Recovery Checks

After the host is stable again:

1. Run a fresh restic backup:

```bash
sudo systemctl start restic-backups-nixos-minipc
```

2. Check that Healthchecks received the run.

3. Confirm the backup repository is still usable:

```bash
sudo restic-nixos-minipc snapshots
```

4. Confirm the host responds to LAN services and DNS as expected.

## Minimal Recovery Checklist

If time is short, do this:

1. Fresh install NixOS.
2. Clone repo.
3. Replace `hosts/nixos-minipc/hardware-configuration.nix`.
4. Restore `/var/lib/agenix/identity` if available.
5. `sudo nixos-rebuild switch --flake .#nixos-minipc`
6. Restore restic snapshot into `/srv/appdata`, `/var/lib/agenix/identity`, `/etc/ssh`.
7. Rebuild once more.
8. Restart services.
9. Verify Caddy, Pi-hole, Karakeep, Jellyfin, and the arr stack.
