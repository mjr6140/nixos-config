# nixos-desktop Backup Recovery

This runbook covers backup and restore operations for `nixos-desktop`.

## 1. High Level Configuration

`nixos-desktop` uses native `services.restic.backups` for the underlying backup job:

- raw restic service:
  - `restic-backups-nixos-desktop.service`
- direct restic wrapper:
  - `restic-nixos-desktop`

Healthchecks and scheduling are handled by a wrapper systemd service and timer:

- wrapper service:
  - `restic-backups-desktop-window.service`
- automatic timer:
  - `restic-backups-desktop-window.timer`

The backup target is:

- NAS restic repository over SFTP:
  - `sftp:restic@10.12.1.99:/mnt/tank/backup-repos/restic/nixos-desktop`

Runtime secret material is provided by agenix:

- `/run/agenix/restic-nixos-desktop.env`
- `/run/agenix/restic-nixos-desktop-ssh`
- host identity:
  - `/var/lib/agenix/identity`

## 2. Where And When Backups Run Automatically

Automatic desktop backups run hourly via:

```sh
systemctl status restic-backups-desktop-window.timer
```

That timer starts:

```sh
restic-backups-desktop-window.service
```

The wrapper service:

- sends Healthchecks `start`
- runs `restic-backups-nixos-desktop.service`
- sends Healthchecks success or failure status

## 3. How To Run A Manual Backup

For a normal manual run with the same behavior as the timer:

```sh
sudo systemctl start --wait restic-backups-desktop-window.service
```

Inspect logs:

```sh
sudo journalctl -u restic-backups-desktop-window.service -n 100 --no-pager
sudo journalctl -u restic-backups-nixos-desktop.service -n 100 --no-pager
```

For direct restic inspection commands:

```sh
sudo restic-nixos-desktop snapshots
```

## 4. How To Restore A Single File Or Subset Of Files

Inspect snapshots:

```sh
sudo restic-nixos-desktop snapshots
```

Inspect files in a snapshot:

```sh
sudo restic-nixos-desktop ls latest
```

Restore into a temporary directory:

```sh
sudo mkdir -p /tmp/restic-restore
sudo restic-nixos-desktop restore latest --target /tmp/restic-restore
```

Copy back only what you need:

```sh
sudo rsync -aHAX /tmp/restic-restore/home/matt/path/to/file /home/matt/path/to/file
sudo rsync -aHAX /tmp/restic-restore/mnt/storage/Photos/some/subdir/ /mnt/storage/Photos/some/subdir/
```

## 5. How To Restore A Full Backup

Restore into a temporary directory first:

```sh
sudo mkdir -p /tmp/restic-restore
sudo restic-nixos-desktop restore latest --target /tmp/restic-restore
```

Then copy the restored trees into place:

```sh
sudo rsync -aHAX /tmp/restic-restore/home/matt/ /home/matt/
sudo rsync -aHAX /tmp/restic-restore/mnt/storage/Photos/ /mnt/storage/Photos/
```

Do not blindly overwrite a live desktop session unless a full rollback is intentional.

## 6. How To Rebuild The Host On Hardware Failure

You need:

- this git repo including tracked `secrets/*.age`
- a key that can decrypt agenix secrets, such as your `matt` key
- the previous host identity if available:
  - `/var/lib/agenix/identity`
- NAS access for the `restic` user

Recommended order:

1. Install fresh NixOS on replacement hardware.
2. Clone the repo to `/home/matt/nixos-config`.
3. Replace `hosts/nixos-desktop/hardware-configuration.nix` with the new generated hardware config.
4. Restore the old host agenix identity if you have it:

```sh
sudo install -d -m 700 /var/lib/agenix
sudo install -m 600 /path/to/identity /var/lib/agenix/identity
```

5. Rebuild the host:

```sh
cd /home/matt/nixos-config
sudo nixos-rebuild switch --flake .#nixos-desktop
```

6. Confirm runtime secrets exist:

```sh
sudo ls -l /run/agenix/restic-nixos-desktop.env
sudo ls -l /run/agenix/restic-nixos-desktop-ssh
```

7. Restore data:

```sh
sudo restic-nixos-desktop snapshots
sudo mkdir -p /tmp/restic-restore
sudo restic-nixos-desktop restore latest --target /tmp/restic-restore
sudo rsync -aHAX /tmp/restic-restore/home/matt/ /home/matt/
sudo rsync -aHAX /tmp/restic-restore/mnt/storage/Photos/ /mnt/storage/Photos/
```

If the old host identity is not available, make sure you can still decrypt the agenix secrets with your `matt` key, rebuild once, then restore or re-establish the host identity afterward.
