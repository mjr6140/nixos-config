# nixos-minipc Backup Recovery

This runbook covers backup and restore operations for `nixos-minipc`.

## 1. High Level Configuration

`nixos-minipc` uses native `services.restic.backups` for two backup targets:

- local NAS backup service:
  - `restic-backups-nixos-minipc.service`
- VPS backup service:
  - `restic-backups-nixos-minipc-vps.service`

Generated direct restic wrappers:

- `restic-nixos-minipc`
- `restic-nixos-minipc-vps`

A wrapper service orchestrates the full backup window and Healthchecks:

- wrapper service:
  - `restic-backups-window.service`
- automatic timer:
  - `restic-backups-window.timer`

Backup targets:

- NAS repository via mounted NFS export:
  - `/mnt/backup-repos/restic/nixos-minipc`
- VPS repository over SFTP:
  - `sftp:restic@185.45.112.73:/data/backup-repos/restic/nixos-minipc`

Runtime secret material is provided by agenix:

- `/run/agenix/restic-nixos-minipc.env`
- `/run/agenix/restic-nixos-minipc-vps.env`
- `/run/agenix/restic-nixos-minipc-vps-ssh`
- host identity:
  - `/var/lib/agenix/identity`

## 2. Where And When Backups Run Automatically

Automatic minipc backups run through:

```sh
systemctl status restic-backups-window.timer
```

That timer starts:

```sh
restic-backups-window.service
```

The wrapper service:

- stops any stacks marked `backup.stopForBackup = true`
- pings Healthchecks for the NAS target
- runs `restic-backups-nixos-minipc.service`
- pings Healthchecks for the VPS target
- runs `restic-backups-nixos-minipc-vps.service`
- restarts stopped stacks on exit

## 3. How To Run A Manual Backup

Run the full backup window with the normal orchestration:

```sh
sudo systemctl start --wait restic-backups-window.service
```

Inspect logs:

```sh
sudo journalctl -u restic-backups-window.service -n 100 --no-pager
sudo journalctl -u restic-backups-nixos-minipc.service -n 100 --no-pager
sudo journalctl -u restic-backups-nixos-minipc-vps.service -n 100 --no-pager
```

For direct restic inspection commands:

```sh
sudo restic-nixos-minipc snapshots
sudo restic-nixos-minipc-vps snapshots
```

## 4. How To Restore A Single File Or Subset Of Files

Inspect snapshots from the target you want:

```sh
sudo restic-nixos-minipc snapshots
sudo restic-nixos-minipc-vps snapshots
```

Inspect files in the snapshot:

```sh
sudo restic-nixos-minipc ls latest
```

Restore into a temporary directory:

```sh
sudo mkdir -p /tmp/restic-restore
sudo restic-nixos-minipc restore latest --target /tmp/restic-restore
```

Copy back only what you need. Common examples:

```sh
sudo rsync -aHAX /tmp/restic-restore/srv/appdata/some-service/ /srv/appdata/some-service/
sudo rsync -aHAX /tmp/restic-restore/etc/ssh/ /etc/ssh/
sudo rsync -aHAX /tmp/restic-restore/var/lib/agenix/identity /var/lib/agenix/identity
```

## 5. How To Restore A Full Backup

Restore the latest snapshot into a temporary directory:

```sh
sudo mkdir -p /tmp/restic-restore
sudo restic-nixos-minipc restore latest --target /tmp/restic-restore
```

Restore the important host state:

```sh
sudo rsync -aHAX /tmp/restic-restore/srv/appdata/ /srv/appdata/
sudo rsync -aHAX /tmp/restic-restore/var/lib/agenix/identity /var/lib/agenix/identity
sudo rsync -aHAX /tmp/restic-restore/etc/ssh/ /etc/ssh/
sudo chmod 600 /var/lib/agenix/identity
```

Rebuild again after restoring identity material:

```sh
cd /home/matt/nixos-config
sudo nixos-rebuild switch --flake .#nixos-minipc
```

## 6. How To Rebuild The Host On Hardware Failure

You need:

- this git repo including tracked `secrets/*.age`
- a key that can decrypt agenix secrets, such as your `matt` key
- the previous host age identity if available:
  - `/var/lib/agenix/identity`
- the previous SSH host keys if available:
  - `/etc/ssh`
- NAS exports for content, media, and backup repos
- the backup targets:
  - `/mnt/tank/backup-repos/restic/nixos-minipc`
  - `sftp:restic@185.45.112.73:/data/backup-repos/restic/nixos-minipc`

Recommended order:

1. Install fresh NixOS on replacement hardware.
2. Clone the repo to `/home/matt/nixos-config`.
3. Replace `hosts/nixos-minipc/hardware-configuration.nix` with the new generated hardware config.
4. Restore `/var/lib/agenix/identity` and `/etc/ssh` first if you have them.
5. Rebuild the host:

```sh
cd /home/matt/nixos-config
sudo nixos-rebuild switch --flake .#nixos-minipc
```

6. Confirm NFS mounts work:

```sh
ls /srv/content/data
ls /srv/content/media
ls /mnt/backup-repos
```

7. Confirm runtime secrets exist:

```sh
sudo ls -l /run/agenix
sudo ls -l /run/agenix/restic-nixos-minipc.env
sudo ls -l /run/agenix/restic-nixos-minipc-vps.env
sudo ls -l /run/agenix/restic-nixos-minipc-vps-ssh
```

8. Restore the host data:

```sh
sudo mkdir -p /tmp/restic-restore
sudo restic-nixos-minipc restore latest --target /tmp/restic-restore
sudo rsync -aHAX /tmp/restic-restore/srv/appdata/ /srv/appdata/
sudo rsync -aHAX /tmp/restic-restore/var/lib/agenix/identity /var/lib/agenix/identity
sudo rsync -aHAX /tmp/restic-restore/etc/ssh/ /etc/ssh/
sudo chmod 600 /var/lib/agenix/identity
```

9. Rebuild again so the host runs against the restored identity material:

```sh
cd /home/matt/nixos-config
sudo nixos-rebuild switch --flake .#nixos-minipc
```
