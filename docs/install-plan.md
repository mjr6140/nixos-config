# NixOS Installation Guide: Gaming & Development

This guide follows a chronological path to a fully optimized NixOS system using **Btrfs**, **Flakes**, and **Home Manager**.

---

## Phase 1: Disk Partitioning & Btrfs Layout
*Run these commands from the NixOS Live Environment terminal.*

> [!IMPORTANT]
> **Firmware Requirement**: This guide assumes your system (or VM) is configured to use **UEFI**. Ensure "Legacy Boot" or "CSM" is disabled in your BIOS settings.

### 1. Identify Your Disk (Safety First)
Disk names like `/dev/nvme3n1` can change between reboots. It is **strongly recommended** to use stable identifiers in `/dev/disk/by-id/`.

Run this to find your disk's stable ID (look for `CT1000P3SSD8`):
```bash
ls -l /dev/disk/by-id/ | grep nvme
```

For this guide, we will set a variable to make the following commands copy-paste safe. Replace the path below with your specific ID:
```bash
# Your stable disk ID
export DISK="/dev/disk/by-id/nvme-CT1000P3SSD8_2323E6DF96AF"
```

### 2. Partitioning
```bash
# Create GPT partition table
gdisk $DISK
# Command: o (New partition table)
# Command: n (New partition) -> 1 (Partition number) -> Default start -> +1G -> Type: ef00 (EFI)
# Command: n (New partition) -> 2 (Partition number) -> Default start -> Default end -> Type: 8300 (Linux)
# Command: w (Write and exit)
```

### 3. Format
```bash
mkfs.fat -F 32 -n boot ${DISK}-part1
mkfs.btrfs -L nixos ${DISK}-part2
```

### 4. Create Subvolumes
```bash
mount ${DISK}-part2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
umount /mnt
```

### 5. Mount with Performance Options
```bash
# Mount root
mount -o compress=zstd,noatime,discard=async,subvol=@ ${DISK}-part2 /mnt

# Mount dependencies
mkdir -p /mnt/{home,nix,var/log,boot}
mount -o compress=zstd,noatime,discard=async,subvol=@home ${DISK}-part2 /mnt/home
mount -o compress=zstd,noatime,discard=async,noacl,subvol=@nix ${DISK}-part2 /mnt/nix
mount -o compress=zstd,noatime,discard=async,subvol=@log ${DISK}-part2 /mnt/var/log
mount ${DISK}-part1 /mnt/boot
```

---

## Phase 2: Configuration & File Setup

### 1. Initial Generation
```bash
nixos-generate-config --root /mnt
```

> [!IMPORTANT]
> **Verify Mount Options**: After generation, check `/mnt/etc/nixos/hardware-configuration.nix`. The generator may not capture all Btrfs mount options. Ensure your `fileSystems` entries include `compress=zstd`, `noatime`, and `discard=async`.

### 2. Organize Repo
Clone your config repository or move the prepared files to `/mnt/etc/nixos/`.

The configuration is split into several files for clarity:
- **Flake Entrypoint**: `flake.nix` (defines inputs and host outputs)
- **Host Config**: `hosts/nixos-desktop/configuration.nix` (system-wide settings)
- **User Config**: `home/matt/home.nix` (Home Manager settings)

### 3. Verify Files
Ensure the following files are in place:
- `/mnt/etc/nixos/flake.nix`
- `/mnt/etc/nixos/hosts/nixos-desktop/configuration.nix`
- `/mnt/etc/nixos/hosts/nixos-desktop/hardware-configuration.nix` (Generated in step 1)
- `/mnt/etc/nixos/home/matt/home.nix`

---

## Phase 3: The Final Install
```bash
cd /mnt/etc/nixos
nixos-install --flake .#nixos-desktop
```

### 2. Set Your User Password
The user `matt` is already defined in your configuration, but they don't have a password yet. You should set it now while still in the live environment:

```bash
# Enter the new system
nixos-enter --root /mnt

# Set the password for your user
passwd matt

# (Optional) Set root password if you didn't during nixos-install
passwd root

# Exit the new system
exit
```

---

## Phase 4: Post-Install & Maintenance

### 1. Set up the Local Repository (Recommended)
Direct usage of `/etc/nixos` is discouraged when using Flakes. Instead, manage your configuration in your home directory to avoid permission issues and treat it like any other software project.

1.  **Clone or Move**:
    ```bash
    mkdir -p ~/code
    # Option A: Move the config we installed with
    sudo mv /etc/nixos ~/code/nixos-config
    sudo chown -R matt:users ~/code/nixos-config
    
    # Option B: Clone fresh from Git
    # git clone https://github.com/yourname/nixos-config ~/code/nixos-config
    ```

2.  **Preserve Hardware Config (If Cloning Fresh)**:
    If you chose Option B, you must copy the machine-specific hardware scan:
    ```bash
    cp /etc/nixos/hardware-configuration.nix ~/code/nixos-config/hosts/nixos-desktop/
    git add hosts/nixos-desktop/hardware-configuration.nix
    ```

### 2. Applying Changes
From now on, run all commands from your local repository:
```bash
cd ~/code/nixos-config
sudo nixos-rebuild switch --flake .#nixos-desktop
```

### 3. Updating Packages
```bash
nix flake update
sudo nixos-rebuild switch --flake .#nixos-desktop
```

---

## Phase 5: Troubleshooting & Recovery

### 1. "No Bootable Device" or "Bootmanager Failed"
If your system fails to boot after installation, it is likely because the EFI variables weren't set correctly or the BIOS/UEFI mode was mismatched.

**To fix without a full reinstall:**
1. Boot the NixOS Live ISO (Ensure it is booted in **UEFI mode**).
2. Mount your partitions (following the commands in Phase 1, Step 5).
3. Re-run the installation command:
   ```bash
   cd /mnt/etc/nixos
   nixos-install --flake .#nixos-vm  # Or nixos-desktop
   ```
   This will re-install the bootloader into the EFI partition and update the UEFI boot entries.

### 2. Verifying the Bootloader
Before rebooting, you can verify that `systemd-boot` was installed correctly by checking the files on the EFI partition:

1. **Check for the EFI binary**:
   ```bash
   ls /mnt/boot/EFI/systemd/systemd-bootx64.efi
   # OR (default fallback location)
   ls /mnt/boot/EFI/BOOT/BOOTX64.EFI
   ```

2. **Check for NixOS boot entries**:
   Each time you install or change the generation, a `.conf` file is created here.
   ```bash
   ls /mnt/boot/loader/entries/
   ```
   You should see at least one file named something like `nixos-generation-1.conf`.

3. **Check the bootloader configuration**:
   ```bash
   cat /mnt/boot/loader/loader.conf
   ```
   It should contain `default nixos-generation-1.conf` (or similar).

4. **Verify EFI Variables (Optional)**:
   If you have `efibootmgr` installed in the live environment, you can check if a "Linux Boot Manager" entry exists:
   ```bash
   efibootmgr
   ```

### 3. Out of Memory (OOM) Errors during Installation
If `nixos-install` crashes with an OOM error, you can reduce memory usage with these methods:

**Method A: Create a Temporary Swap File (Recommended)**
This provides extra "virtual" RAM.
```bash
# Create a 4GB swap file in the live environment's RAM disk (or on disk if preferred)
fallocate -l 4G /tmp/swapfile
chmod 600 /tmp/swapfile
mkswap /tmp/swapfile
swapon /tmp/swapfile
```

**Method B: Limit Nix Build Jobs**
Forces Nix to build one thing at a time, using only one core.
```bash
nixos-install --flake .#nixos-vm --max-jobs 1 --cores 1
```

**Method C: Increase VM RAM (VM Only)**
If installing in a VM, shut it down and increase the RAM to at least **8GB** temporarily for the installation process.

---

## Phase 6: Testing in a VM (Recommended)
Before installing on physical hardware, you can test this configuration in a KVM virtual machine.

### 1. Requirements
- Existing Linux host with `virt-manager` and `libvirtd` enabled.
- The repository cloned to the host.

### 2. Configure VM
In `virt-manager`, create a new VM:
- **CPU**: At least 2 cores.
- **Memory**: At least 4GB.
- **Storage**: At least 20GB (Btrfs subvolumes will be created).
- **Network**: Default NAT.
- **Display**: Spice with QXL or Virtio.

> [!IMPORTANT]
> **Firmware (Critical)**:
> 1. Before finishing the "New VM" wizard, check "Customize configuration before install".
> 2. In the **Overview** section, change **Firmware** from `BIOS` to `UEFI (OVMF)`.
> 3. Failure to do this will result in a boot failure after installation, as `systemd-boot` requires UEFI.

### 3. Run Install
Boot the VM with a NixOS ISO and run:
```bash
# Inside the VM
sudo nixos-install --flake .#nixos-vm
```

---

## Appendix: Software Manifest (Verification Checklist)

| Requirement | Scope | Note |
| :--- | :--- | :--- |
| Nvidia Drivers | System | Open drivers with power management & settings GUI. |
| Steam | System | `programs.steam.enable = true` in config. |
| Antigravity IDE | User | Dedicated Flake input and home.nix package. |
| Optimized Kernel | System | Latest stable kernel |
| Virtualization | System | KVM + Virt-Manager + Docker. |
| Media | System | VLC & PipeWire (ALSA/Pulse). |
| Desktop Environment | System | GNOME + Niri + DMS. |
| Shell Enhancements | User | starship, fzf, zoxide, eza, bat. |
| Communication | System | Thunderbird & Brave. |

