# Fileserver VM

This host provides a small mergerfs + SnapRAID storage pool with Samba shares.

## Storage Layout

- Data disks mount at `/mnt/disk1`, `/mnt/disk2`, and `/mnt/disk3`
- Per-disk data directories live at `/mnt/disk*/data`
- Parity disk mounts at `/mnt/parity`
- The pooled view is mounted at `/srv/storage` via `mergerfs`

Important mergerfs behavior:

- New files written to `/srv/storage` are placed on a single backing disk
- With `category.create=mfs`, mergerfs chooses the disk with the most free space
- `minfreespace=1G` must be satisfied on a backing disk before mergerfs will create files there

## Samba

The fileserver exports two authenticated shares:

- `shared` at `/srv/storage/shares/shared`
- `media` at `/srv/storage/shares/media`

Access notes:

- Use `matt` as the current Samba user
- Shares require a Samba password set with `smbpasswd`
- Connect directly to a share path, for example `smb://<vm-ip>/shared`
- The VM IP can change; check it with `ip addr`

Useful commands:

```sh
sudo smbpasswd -a matt
sudo pdbedit -L
sudo testparm -s
systemctl status samba-smbd samba-nmbd samba-wsdd
```

The share directories and permissions are created declaratively by the system:

- `/srv/storage/shares`
- `/srv/storage/shares/shared`
- `/srv/storage/shares/media`

## SnapRAID

SnapRAID uses:

- parity file: `/mnt/parity/snapraid.parity`
- content files on each array disk
- one extra content file at `/var/lib/snapraid/snapraid.content`

Schedule:

- sync daily at `03:00`
- scrub every Sunday at `04:00`

Useful commands:

```sh
sudo systemctl start snapraid-sync.service
sudo systemctl start snapraid-scrub.service
systemctl status snapraid-sync.service snapraid-scrub.service
journalctl -u snapraid-sync.service -n 100 --no-pager
journalctl -u snapraid-scrub.service -n 100 --no-pager
```

Direct SnapRAID commands:

```sh
sudo snapraid status
sudo snapraid diff
sudo snapraid sync
sudo snapraid scrub
```

For a fresh or reset array, SnapRAID may report that the array appears empty or that old files are missing from a disk. If the current disk state is correct and you want to accept it as the new baseline, initialize parity with:

```sh
sudo snapraid --force-empty sync
```

Use that only when you are intentionally establishing a new baseline.

## Rebuild

Apply this host config with:

```sh
sudo nixos-rebuild switch --flake .#nixos-fileserver-vm
```
